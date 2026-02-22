package funkin.gameplay;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.group.FlxGroup;
import funkin.data.MetaData;
import funkin.scripting.ScriptHandler;
import funkin.scripting.HScriptInstance;
import funkin.gameplay.GameState;
import sys.FileSystem;

/**
	* UIScriptedManager — A UIManager fully controlled by HScript.

	* If the requested script does not exist or fails, the default script is loaded automatically.

	* *

	* ─── API exposed to the script ──────────────────────────────────────────────

	* // Construction

	* 	makeSprite(x, y) → FlxSprite (scrollFactor=0, assigned camHUD)

	* 	makeText(x, y, text, size) → FlxText (scrollFactor=0, assigned camHUD)

	* 	makeBar(x, y, w, h, obj, var, min, max) → FlxBar (RIGHT_TO_LEFT, scrollFactor=0, camHUD)

	* 	uiAdd(obj) → adds to the group and assigns camHUD

	* 	uiRemove(obj) → removes from the group

	* 	screenCenterX(obj)

	* 	screenCenterY(obj)

	* // Manual pool (replicates UIManager.getFromPool)

	* // _getFromPool(array) is used directly in the script with makeSprite+uiAdd

	* // Available classes in the script

	* 	HealthIcon, ScoreManager, FlxMath, StringTools

	* 	PIXEL_ZOOM, BORDER_OUTLINE, BORDER_SHADOW, BORDER_NONE

	* // Context references

	* 	camHUD, gameState, uiGroup, metaData

	* ─── Callbacks from the script ──────────────────────── ───────────────────────── 
	* 	onCreate() 
	* 	onUpdate(elapsed) 
	* 	onBeatHit(beat) 
	* 	onStepHit(step) 
	* 	onRatingPopup(ratingName, combo) 
	* 	onMissPopup() 
	* 	onScoreUpdate(score, misses, accuracy) ← optional, script can ignore it 
	* 	onHealthUpdate(health, percent) ← optional 
	* 	onIconsSet(p1, p2) 
	* 	onStageSet(stage) 
	* 	onDestroy()
 */
class UIScriptedManager extends FlxGroup
{
	// ─── Script ─────────────────────────────────────────────────────────────
	private var uiScript:HScriptInstance;

	// ─── Referencias ────────────────────────────────────────────────────────
	private var camHUD:FlxCamera;
	private var gameState:GameState;
	private var metaData:MetaData;

	// ─── Constructor ────────────────────────────────────────────────────────

	public function new(camHUD:FlxCamera, gameState:GameState, metaData:MetaData)
	{
		super();

		this.camHUD = camHUD;
		this.gameState = gameState;
		this.metaData = metaData;

		loadUIScript(metaData.ui);
	}

	// ─── Carga del script ────────────────────────────────────────────────────

	private function loadUIScript(name:String):Void
	{
		// Buscar en el mod activo primero, luego en assets/.
		// Estructura soportada:
		//   mods/{mod}/data/ui/{name}/script.hx   ← Cool Engine layout
		//   mods/{mod}/assets/data/ui/{name}/script.hx ← Psych layout
		//   assets/data/ui/{name}/script.hx        ← base
		var path:String = null;

		#if sys
		if (mods.ModManager.isActive())
		{
			final modRoot = mods.ModManager.modRoot();
			for (candidate in [
				'$modRoot/data/ui/$name/script.hx',
				'$modRoot/assets/data/ui/$name/script.hx'
			])
			{
				if (FileSystem.exists(candidate)) { path = candidate; break; }
			}
		}
		#end

		if (path == null)
		{
			final assetPath = 'assets/data/ui/$name/script.hx';
			if (FileSystem.exists(assetPath)) path = assetPath;
		}

		if (path == null)
		{
			if (name != 'default')
			{
				trace('[UIScriptedManager] "$name" no encontrado, cargando default...');
				loadUIScript('default');
			}
			else
			{
				trace('[UIScriptedManager] ERROR: UI script "default" no existe. HUD vacío.');
			}
			return;
		}

		trace('[UIScriptedManager] Cargando UI script desde: $path');
		uiScript = ScriptHandler.loadScript(path, 'ui');

		if (uiScript == null)
		{
			trace('[UIScriptedManager] Error al parsear script "$name", cargando default...');
			if (name != 'default')
				loadUIScript('default');
			return;
		}

		exposeUIAPI();
		uiScript.call('onCreate', []);
		trace('[UIScriptedManager] Script de UI activo: "$name" (desde $path)');
	}

	// ─── API expuesta al script ──────────────────────────────────────────────

	private function exposeUIAPI():Void
	{
		if (uiScript == null)
			return;

		var self = this;

		// ── Referencias de contexto ────────────────────────────────────────
		uiScript.set('camHUD', camHUD);
		uiScript.set('gameState', gameState);
		uiScript.set('uiGroup', this);
		uiScript.set('metaData', metaData);

		// ── Clases que el script necesita para replicar UIManager ──────────

		// HealthIcon — para new HealthIcon(name, isPlayer)
		uiScript.set('HealthIcon', funkin.gameplay.objects.character.HealthIcon);

		// ScoreManager — para scoreManager.getHUDText(gameState)
		uiScript.set('ScoreManager', funkin.gameplay.objects.hud.ScoreManager);

		// FlxMath — para remapToRange y lerp
		uiScript.set('FlxMath', flixel.math.FlxMath);

		// StringTools — para StringTools.startsWith(curStage, 'school')
		uiScript.set('StringTools', StringTools);

		// PlayStateConfig.PIXEL_ZOOM expuesto como constante directa
		uiScript.set('PIXEL_ZOOM', funkin.gameplay.PlayStateConfig.PIXEL_ZOOM);

		// setBorderStyle wrapper — HScript no puede pasar enums nativos de Haxe directamente.
		// En vez de exponer las constantes (que llegan como Int y crashean en applyBorderStyle),
		// exponemos una función que llama a setBorderStyle con el enum correcto desde Haxe.
		uiScript.set('setTextBorder', function(txt:flixel.text.FlxText, style:String, color:flixel.util.FlxColor, ?size:Float = 1, ?quality:Float = 1):Void
		{
			var s = switch (style.toLowerCase())
			{
				case 'outline': flixel.text.FlxText.FlxTextBorderStyle.OUTLINE;
				case 'outline_fast': flixel.text.FlxText.FlxTextBorderStyle.OUTLINE_FAST;
				case 'shadow': flixel.text.FlxText.FlxTextBorderStyle.SHADOW;
				default: flixel.text.FlxText.FlxTextBorderStyle.NONE;
			};
			txt.setBorderStyle(s, color, size, quality);
		});

		// ── Helpers de creación (scrollFactor=0 y camHUD ya asignados) ─────

		uiScript.set('makeSprite', function(?x:Float = 0, ?y:Float = 0):flixel.FlxSprite
		{
			var spr = new flixel.FlxSprite(x, y);
			spr.scrollFactor.set();
			spr.cameras = [camHUD];
			return spr;
		});

		uiScript.set('makeText', function(?x:Float = 0, ?y:Float = 0, ?text:String = '', ?size:Int = 20):flixel.text.FlxText
		{
			var t = new flixel.text.FlxText(x, y, 0, text, size);
			t.scrollFactor.set();
			t.cameras = [camHUD];
			return t;
		});

		// makeBar siempre RIGHT_TO_LEFT (único caso de uso = health bar)
		uiScript.set('makeBar', function(x:Float, y:Float, w:Int, h:Int, obj:Dynamic, varName:String, min:Float, max:Float):flixel.ui.FlxBar
		{
			var bar = new flixel.ui.FlxBar(x, y, flixel.ui.FlxBar.FlxBarFillDirection.RIGHT_TO_LEFT, w, h, obj, varName, min, max);
			bar.scrollFactor.set();
			bar.cameras = [camHUD];
			return bar;
		});

		// ── uiAdd / uiRemove ───────────────────────────────────────────────

		// uiAdd: añade el objeto al grupo Y le asigna camHUD si es FlxObject
		uiScript.set('uiAdd', function(obj:flixel.FlxBasic):flixel.FlxBasic
		{
			if (Std.isOfType(obj, flixel.FlxObject))
				cast(obj, flixel.FlxObject).cameras = [camHUD];
			self.add(obj);
			return obj;
		});

		// uiRemove: elimina del grupo (true = eliminar de memoria del grupo)
		uiScript.set('uiRemove', function(obj:flixel.FlxBasic):Void
		{
			self.remove(obj, true);
		});

		// ── Utilidades ─────────────────────────────────────────────────────

		uiScript.set('screenCenterX', function(spr:flixel.FlxObject):Void spr.screenCenter(flixel.util.FlxAxes.X));

		uiScript.set('screenCenterY', function(spr:flixel.FlxObject):Void spr.screenCenter(flixel.util.FlxAxes.Y));
	}

	// ─── Ciclo de vida ───────────────────────────────────────────────────────

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		uiScript?.call('onUpdate', [elapsed]);
	}

	// ─── Callbacks del juego → script ────────────────────────────────────────

	public function onBeatHit(beat:Int):Void
	{
		uiScript?.call('onBeatHit', [beat]);
	}

	public function onStepHit(step:Int):Void
	{
		uiScript?.call('onStepHit', [step]);
	}

	public function showRatingPopup(ratingName:String, combo:Int):Void
	{
		if (metaData.hideRatings)
			return;
		uiScript?.call('onRatingPopup', [ratingName, combo]);
	}

	public function showMissPopup():Void
	{
		uiScript?.call('onMissPopup', []);
	}

	public function setIcons(p1:String, p2:String):Void
	{
		uiScript?.call('onIconsSet', [p1, p2]);
	}

	public function setStage(stage:String):Void
	{
		uiScript?.call('onStageSet', [stage]);
	}

	// ─── Acceso a iconos (compatibilidad con PlayState) ───────────────────────
	// PlayState puede leer iconP1/iconP2 si el script los expone como variables.
	public var iconP1(get, null):funkin.gameplay.objects.character.HealthIcon;

	function get_iconP1():funkin.gameplay.objects.character.HealthIcon
		return uiScript?.get('iconP1');

	public var iconP2(get, null):funkin.gameplay.objects.character.HealthIcon;

	function get_iconP2():funkin.gameplay.objects.character.HealthIcon
		return uiScript?.get('iconP2');

	// ─── Destrucción ─────────────────────────────────────────────────────────

	override function destroy():Void
	{
		uiScript?.call('onDestroy', []);
		uiScript?.destroy();
		uiScript = null;
		super.destroy();
	}
}
