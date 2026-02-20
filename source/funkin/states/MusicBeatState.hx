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
#if debug
import funkin.debug.DebugConsole;
#end

class MusicBeatState extends FlxUIState
{
	private var lastBeat:Float = 0;
	private var lastStep:Float = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;
	private var controls(get, never):Controls;

	// ── Cache para búsqueda incremental en bpmChangeMap ───────────────────────
	// El mapa BPM está ordenado — como songPosition es monotónica, solo
	// necesitamos avanzar este puntero, nunca retroceder. O(1) amortizado.
	private var _bpmIdx:Int = 0;

	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	#if mobileC
	var _virtualpad:FlxVirtualPad;

	var trackedinputs:Array<FlxActionInput> = [];

	public function addVirtualPad(?DPad:FlxDPadMode, ?Action:FlxActionMode) {
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
	
	override function destroy() {
		controls.removeFlxInput(trackedinputs);
		super.destroy();
	}
	#else
	public function addVirtualPad(?DPad, ?Action){};
	#end
	
	#if !mobileC
	override function destroy():Void
	{
		Paths.clearCache();
		super.destroy();
	}
	#end

	override function create()
	{
		if (transIn != null)
			trace('reg ' + transIn.region);

		// Resetear puntero BPM para este nuevo state
		_bpmIdx = 0;

		super.create();

		// Disparar animación de entrada (StateTransition.onStateCreated
		// comprueba si hay un intro pendiente antes de hacer nada)
		StateTransition.onStateCreated();
	}

	override function update(elapsed:Float)
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

	public function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
	}

	/**
	 * Calcula el step actual.
	 *
	 * OPTIMIZACIÓN: búsqueda incremental en vez de loop completo desde 0.
	 * El bpmChangeMap está ordenado por songTime. Como Conductor.songPosition
	 * normalmente solo avanza, basta con mover el puntero hacia adelante.
	 * Si la posición retrocede (seek/restart), el puntero se resetea a 0.
	 *
	 * Coste original: O(n) por frame (n = cambios de BPM).
	 * Coste nuevo:    O(1) amortizado (≈ O(k) donde k = saltos de BPM en el frame).
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

		// Si la posición retrocedió (seek o restart de canción), releer desde 0
		if (_bpmIdx > 0 && pos < map[_bpmIdx].songTime)
			_bpmIdx = 0;

		// Avanzar puntero mientras el próximo evento ya pasó
		while (_bpmIdx + 1 < len && pos >= map[_bpmIdx + 1].songTime)
			_bpmIdx++;

		final ev = map[_bpmIdx];
		curStep = ev.stepTime + Math.floor((pos - ev.songTime) / Conductor.stepCrochet);
	}

	public function stepHit():Void
	{
		if (curStep % 4 == 0)
			beatHit();
	}

	public function beatHit():Void
	{
		// override in subclasses
	}
}
