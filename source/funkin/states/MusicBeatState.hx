package funkin.states;

import funkin.data.Conductor.BPMChangeEvent;
import funkin.data.Conductor;
import flixel.FlxG;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.FlxUIState;
import flixel.math.FlxRect;
import flixel.util.FlxTimer;
import data.PlayerSettings;
import flixel.FlxCamera;
#if mobileC
import ui.FlxVirtualPad;
import flixel.input.actions.FlxActionInput;
#end
import funkin.gameplay.controls.Controls;
import ui.SoundTray;
import funkin.transitions.StateTransition;
import funkin.scripting.StateScriptHandler;
#if debug
import funkin.debug.DebugConsole;
#end

/**
 * MusicBeatState v2 — base de todos los estados del juego.
 *
 * Novedades:
 *   • Auto-scripting: si hay scripts en assets/states/{ClassName}/, los carga
 *     automáticamente sin que cada state tenga que hacerlo manualmente.
 *   • Propagación de beatHit/stepHit a scripts.
 *   • Hook onStateCreate/onStateDestroy para scripts globales.
 *   • autoScriptLoad: bool para deshabilitar si el state lo gestiona manualmente.
 */
class MusicBeatState extends FlxUIState
{
	private var lastBeat : Float = 0;
	private var lastStep : Float = 0;

	private var curStep : Int = 0;
	private var curBeat : Int = 0;
	private var controls(get, never):Controls;

	/** Si true, carga automáticamente scripts de assets/states/{ClassName}/. */
	public var autoScriptLoad:Bool = true;

	// Cache BPM incremental
	private var _bpmIdx:Int = 0;

	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	#if mobileC
	var _virtualpad:FlxVirtualPad;
	var trackedinputs:Array<FlxActionInput> = [];

	public function addVirtualPad(?DPad:FlxDPadMode, ?Action:FlxActionMode)
	{
		_virtualpad = new FlxVirtualPad(DPad, Action);
		_virtualpad.alpha = 0.75;
		add(_virtualpad);
		controls.setVirtualPad(_virtualpad, DPad, Action);
		trackedinputs = controls.trackedinputs;
		controls.trackedinputs = [];

		var padscam = new FlxCamera();
		FlxG.cameras.add(padscam);
		padscam.bgColor.alpha = 0;
		_virtualpad.cameras = [padscam];

		#if android
		controls.addAndroidBack();
		#end
	}

	override function destroy()
	{
		_onDestroy();
		controls.removeFlxInput(trackedinputs);
		// NOTE: Paths.clearCache() removed — it was called while the NEW state's
		// assets were already loaded, destroying graphics that belong to the
		// incoming state. FunkinCache's postStateSwitch signal handles cleanup.
		super.destroy();
	}
	#else
	public function addVirtualPad(?DPad, ?Action) {}

	override function destroy():Void
	{
		_onDestroy();
		// NOTE: Paths.clearCache() removed — it was called while the NEW state's
		// assets were already loaded, destroying graphics that belong to the
		// incoming state. FunkinCache's postStateSwitch signal handles cleanup.
		super.destroy();
	}
	#end

	override function create():Void
	{
		_bpmIdx = 0;

		super.create();
		StateTransition.onStateCreated();

		// Auto-cargar scripts si el state lo permite y no los cargó manualmente
		if (autoScriptLoad)
			_autoLoadScripts();

		// GPU caching: liberar RAM de todas las texturas cargadas en este state
		// que ya fueron subidas a VRAM. Esto reduce RAM en menús (240 MB → mucho menos).
		// Se hace 5 frames después para garantizar que todas las texturas tuvieron
		// al menos un draw call antes de disposeImage().
		// PlayState tiene su propio mecanismo más granular — no se doble-flush.
		#if (desktop && cpp && !hl)
		if (!Std.isOfType(this, funkin.gameplay.PlayState))
		{
			var _menuFlushFrames:Int = 0;
			function _onMenuFlush(_:openfl.events.Event):Void {
				if (++_menuFlushFrames < 5) return;
				FlxG.stage.removeEventListener(openfl.events.Event.ENTER_FRAME, _onMenuFlush);
				funkin.cache.PathsCache.instance.flushGPUCache();
				cpp.vm.Gc.run(false); // ciclo leve — no compact() para no causar stutter en menús
			}
			FlxG.stage.addEventListener(openfl.events.Event.ENTER_FRAME, _onMenuFlush);
		}
		#end
	}

	override function update(elapsed:Float):Void
	{
		var oldStep:Int = curStep;

		#if debug
		DebugConsole.update();
		#end

		updateCurStep();
		updateBeat();

		if (oldStep != curStep && curStep > 0)
			stepHit();

		super.update(elapsed);
	}

	// ─── Auto-scripting ───────────────────────────────────────────────────────

	/**
	 * Carga scripts desde assets/states/{ClassName}/ si existen.
	 * Se llama automáticamente al crear el state. Los states que ya
	 * gestionan sus scripts manualmente deben poner `autoScriptLoad = false`
	 * en su `create()` ANTES de llamar a `super.create()`.
	 */
	function _autoLoadScripts():Void
	{
		#if HSCRIPT_ALLOWED
		final className = Type.getClassName(Type.getClass(this)).split('.').pop();
		final folder    = 'assets/states/${className.toLowerCase()}';

		#if sys
		if (!sys.FileSystem.exists(folder)) return;
		#end

		// Solo cargamos si no hay scripts ya activos para este state
		if (Lambda.count(StateScriptHandler.scripts) == 0)
		{
			StateScriptHandler.init();
			StateScriptHandler.loadStateScripts(className, this);

			if (Lambda.count(StateScriptHandler.scripts) > 0)
			{
				StateScriptHandler.callOnScripts('onCreate', []);
				trace('[MusicBeatState] Auto-scripts cargados para $className.');
			}
		}
		#end
	}

	function _onDestroy():Void
	{
		var soundTray = FlxG.plugins.get(SoundTray);
		if (soundTray != null)
			cast(soundTray, SoundTray).forceHide();

		// BUGFIX: Limpiar scripts de HScript al destruir el state.
		// StateScriptHandler es estático — si los scripts no se limpian aquí,
		// siguen activos con referencias al state destruido. El nuevo state
		// nunca carga sus propios scripts (la guarda Lambda.count == 0 es false)
		// y los scripts viejos crashean al llamar métodos sobre el state muerto.
		#if HSCRIPT_ALLOWED
		StateScriptHandler.clearStateScripts();
		#end
	}

	// ─── BPM / Beat ───────────────────────────────────────────────────────────

	public function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
	}

	/**
	 * Calcula el step actual con búsqueda incremental O(1) amortizado.
	 */
	public function updateCurStep():Void
	{
		final map = Conductor.bpmChangeMap;
		final pos = Conductor.songPosition;
		final len = map.length;

		if (len == 0)
		{
			curStep = Math.floor(pos / Conductor.stepCrochet);
			return;
		}

		if (_bpmIdx > 0 && pos < map[_bpmIdx].songTime)
			_bpmIdx = 0;

		while (_bpmIdx + 1 < len && pos >= map[_bpmIdx + 1].songTime)
			_bpmIdx++;

		final ev = map[_bpmIdx];
		curStep = ev.stepTime + Math.floor((pos - ev.songTime) / Conductor.stepCrochet);
	}

	public function stepHit():Void
	{
		// Propagar a scripts (StateScriptHandler si hay activos)
		#if HSCRIPT_ALLOWED
		if (Lambda.count(StateScriptHandler.scripts) > 0)
			StateScriptHandler.fireRaw('onStepHit', [curStep]);
		#end

		if (curStep % 4 == 0)
			beatHit();
	}

	public function beatHit():Void
	{
		// Propagar a scripts
		#if HSCRIPT_ALLOWED
		if (Lambda.count(StateScriptHandler.scripts) > 0)
			StateScriptHandler.fireRaw('onBeatHit', [curBeat]);
		#end
		// override en subclases
	}
}
