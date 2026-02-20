package funkin.states;

import funkin.data.Conductor.BPMChangeEvent;
import funkin.transitions.StateTransition;
import flixel.FlxG;
import flixel.FlxSubState;
import flixel.FlxCamera;
#if mobileC
import ui.FlxVirtualPad;
import flixel.input.actions.FlxActionInput;
#end
import funkin.data.Conductor;
import data.PlayerSettings;

import funkin.gameplay.controls.Controls;

class MusicBeatSubstate extends FlxSubState
{
	public function new()
	{
		super();
	}

	private var lastBeat:Float = 0;
	private var lastStep:Float = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;
	private var controls(get, never):Controls;

	// Cache para búsqueda incremental en bpmChangeMap (misma optimización que MusicBeatState)
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

	override function create()
	{
		_bpmIdx = 0;
		super.create();

		StateTransition.onStateCreated();
	}

	override function update(elapsed:Float)
	{
		var oldStep:Int = curStep;

		updateCurStep();
		curBeat = Math.floor(curStep / 4);

		if (oldStep != curStep && curStep > 0)
			stepHit();

		super.update(elapsed);
	}

	/**
	 * Búsqueda incremental O(1) amortizado — igual que MusicBeatState.
	 */
	private function updateCurStep():Void
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
		if (curStep % 4 == 0)
			beatHit();
	}

	public function beatHit():Void
	{
		// override in subclasses
	}
}
