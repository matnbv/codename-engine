package funkin.game;

import flixel.util.FlxSignal.FlxTypedSignal;

import funkin.backend.scripting.events.*;
import funkin.backend.system.Conductor;
import funkin.backend.chart.ChartData;
import funkin.backend.system.Controls;
import flixel.tweens.FlxTween;

class StrumLine extends FlxTypedGroup<Strum> {
	/**
	 * Signal that triggers whenever a note is hit. Similar to onPlayerHit and onDadHit, except strumline specific.
	 * To add a listener, do
	 * `strumLine.onHit.add(function(e:NoteHitEvent) {});`
	 */
	public var onHit:FlxTypedSignal<NoteHitEvent->Void> = new FlxTypedSignal<NoteHitEvent->Void>();
	/**
	 * Signal that triggers whenever a note is missed. Similar to onPlayerMiss and onDadMiss, except strumline specific.
	 * To add a listener, do
	 * `strumLine.onMiss.add(function(e:NoteHitEvent) {});`
	 */
	public var onMiss:FlxTypedSignal<NoteHitEvent->Void> = new FlxTypedSignal<NoteHitEvent->Void>();
	/**
	 * Signal that triggers whenever a note is being updated. Similar to onNoteUpdate, except strumline specific.
	 * To add a listener, do
	 * `strumLine.onNoteUpdate.add(function(e:NoteUpdateEvent) {});`
	 */
	public var onNoteUpdate:FlxTypedSignal<NoteUpdateEvent->Void> = new FlxTypedSignal<NoteUpdateEvent->Void>();
	/**
	 * Signal that triggers whenever a note is being updated. Similar to onNoteUpdate, except strumline specific.
	 * To add a listener, do
	 * `strumLine.onNoteUpdate.add(function(e:NoteUpdateEvent) {});`
	 */
	public var onNoteDelete:FlxTypedSignal<SimpleNoteEvent->Void> = new FlxTypedSignal<SimpleNoteEvent->Void>();
	/**
	 * Array containing all of the characters "attached" to those strums.
	 */
	public var characters:Array<Character>;
	/**
	 * Whenever this strumline is controlled by cpu or not.
	 */
	public var cpu(default, set):Bool = false;
	/**
	 * Whenever this strumline is from the opponent side or the player side.
	 */
	public var opponentSide:Bool = false;
	/**
	 * Controls assigned to this strumline.
	 */
	public var controls:Controls = null;
	/**
	 * Chart JSON data assigned to this StrumLine (Codename format)
	 */
	public var data:ChartStrumLine = null;
	/**
	 * Whenever Ghost Tapping is enabled.
	 */
	@:isVar public var ghostTapping(get, set):Null<Bool> = null;
	/**
	 * Group of all of the notes in this strumline. Using `forEach` on this group will only loop through the first notes for performance reasons.
	 */
	public var notes:NoteGroup;
	/**
	 * Whenever alt animation is enabled on this strumline.
	 */
	public var altAnim:Bool = false;

	private function get_ghostTapping() {
		if (this.ghostTapping != null) return this.ghostTapping;
		if (PlayState.instance != null) return PlayState.instance.ghostTapping;
		return false;
	}

	private inline function set_ghostTapping(b:Bool):Bool
		return this.ghostTapping = b;

	private var strumOffset:Float = 0.25;

	public function new(characters:Array<Character>, strumOffset:Float = 0.25, cpu:Bool = false, opponentSide:Bool = true, ?controls:Controls) {
		super();
		this.characters = characters;
		this.strumOffset = strumOffset;
		this.cpu = cpu;
		this.opponentSide = opponentSide;
		this.controls = controls;
		this.notes = new NoteGroup();
	}

	public function generate(strumLine:ChartStrumLine, ?startTime:Float) {
		if (strumLine.notes != null) for(note in strumLine.notes) {
			if (startTime != null && startTime > note.time)
				continue;

			notes.add(new Note(this, note, false));

			if (note.sLen > Conductor.stepCrochet * 0.75) {
				var len:Float = note.sLen;
				var curLen:Float = 0;
				while(len > 10) {
					curLen = Math.min(len, Conductor.stepCrochet);
					notes.add(new Note(this, note, true, curLen, note.sLen - len));
					len -= curLen;
				}
			}
		}
		notes.sortNotes();
	}

	public override function update(elapsed:Float) {
		super.update(elapsed);
		notes.update(elapsed);
	}

	public override function draw() {
		super.draw();
		notes.cameras = cameras;
		notes.draw();
	}

	public inline function updateNotes() {
		notes.forEach(updateNote);
	}

	var __updateNote_strum:Strum;
	public function updateNote(daNote:Note) {
		__updateNote_strum = members[daNote.noteData];
		if (__updateNote_strum == null) return;

		PlayState.instance.__updateNote_event.recycle(daNote, FlxG.elapsed, __updateNote_strum);
		onNoteUpdate.dispatch(PlayState.instance.__updateNote_event);
		if (PlayState.instance.__updateNote_event.cancelled) return;

		if (PlayState.instance.__updateNote_event.__updateHitWindow) {
			daNote.canBeHit = (daNote.strumTime > Conductor.songPosition - (PlayState.instance.hitWindow * daNote.latePressWindow)
				&& daNote.strumTime < Conductor.songPosition + (PlayState.instance.hitWindow * daNote.earlyPressWindow));

			if (daNote.strumTime < Conductor.songPosition - PlayState.instance.hitWindow && !daNote.wasGoodHit)
				daNote.tooLate = true;
		}

		if (cpu && PlayState.instance.__updateNote_event.__autoCPUHit && !daNote.wasGoodHit && daNote.strumTime < Conductor.songPosition) PlayState.instance.goodNoteHit(this, daNote);

		if (daNote.wasGoodHit && daNote.isSustainNote && daNote.strumTime + (daNote.sustainLength) < Conductor.songPosition) {
			deleteNote(daNote);
			return;
		}

		if (daNote.tooLate && !cpu) {
			PlayState.instance.noteMiss(this, daNote);
			return;
		}


		if (PlayState.instance.__updateNote_event.strum == null) return;

		if (PlayState.instance.__updateNote_event.__reposNote) PlayState.instance.__updateNote_event.strum.updateNotePosition(daNote);
		if (daNote.isSustainNote)
			daNote.updateSustain(PlayState.instance.__updateNote_event.strum);
	}

	var __funcsToExec:Array<Note->Void> = [];
	var __pressed:Array<Bool> = [];
	var __justPressed:Array<Bool> = [];
	var __justReleased:Array<Bool> = [];
	var __notePerStrum:Array<Note> = [];

	function __inputProcessPressed(note:Note) {
		if (__pressed[note.strumID] && note.isSustainNote && note.canBeHit && !note.wasGoodHit) {
			PlayState.instance.goodNoteHit(this, note);
		}
	}
	function __inputProcessJustPressed(note:Note) {
		if (__justPressed[note.strumID] && !note.isSustainNote && !note.wasGoodHit && note.canBeHit) {
			if (__notePerStrum[note.strumID] == null) 											__notePerStrum[note.strumID] = note;
			else if (Math.abs(__notePerStrum[note.strumID].strumTime - note.strumTime) <= 2)  	deleteNote(note);
			else if (note.strumTime < __notePerStrum[note.strumID].strumTime)					__notePerStrum[note.strumID] = note;
		}
	}
	public function updateInput(id:Int = 0) {
		updateNotes();

		if (cpu) return;

		__funcsToExec.clear();
		__pressed.clear();
		__justPressed.clear();
		__justReleased.clear();

		__pressed.pushGroup(controls.NOTE_LEFT, controls.NOTE_DOWN, controls.NOTE_UP, controls.NOTE_RIGHT);
		__justPressed.pushGroup(controls.NOTE_LEFT_P, controls.NOTE_DOWN_P, controls.NOTE_UP_P, controls.NOTE_RIGHT_P);
		__justReleased.pushGroup(controls.NOTE_LEFT_R, controls.NOTE_DOWN_R, controls.NOTE_UP_R, controls.NOTE_RIGHT_R);

		var event = PlayState.instance.scripts.event("onKeyShit", EventManager.get(InputSystemEvent).recycle(__pressed, __justPressed, __justReleased, this, id));
		if (event.cancelled) return;

		__pressed = CoolUtil.getDefault(event.pressed, []);
		__justPressed = CoolUtil.getDefault(event.justPressed, []);
		__justReleased = CoolUtil.getDefault(event.justReleased, []);

		__notePerStrum = [for(_ in 0...4) null];


		if (__pressed.contains(true)) {
			for(c in characters)
				if (c.lastAnimContext != DANCE)
					c.__lockAnimThisFrame = true;

			__funcsToExec.push(__inputProcessPressed);
		}
		if (__justPressed.contains(true))
			__funcsToExec.push(__inputProcessJustPressed);

		if (__funcsToExec.length > 0) {
			notes.forEachAlive(function(note:Note) {
				for(e in __funcsToExec) if (e != null) e(note);
			});
		}

		if (!ghostTapping) for(k=>pr in __justPressed) if (pr && __notePerStrum[k] == null) {
			// FUCK YOU
			PlayState.instance.noteMiss(this, null, k, ID);
		}
		for(e in __notePerStrum) if (e != null) PlayState.instance.goodNoteHit(this, e);

		forEach(function(str:Strum) {
			str.updatePlayerInput(__pressed[str.ID], __justPressed[str.ID], __justReleased[str.ID]);
		});
		PlayState.instance.scripts.call("onPostKeyShit");
	}

	public inline function addHealth(health:Float)
		PlayState.instance.health += health * (opponentSide ? -1 : 1);

	public function generateStrums(amount:Int = 4) {
		for (i in 0...4)
		{
			var babyArrow:Strum = new Strum((FlxG.width * strumOffset) + (Note.swagWidth * (i - 2)), PlayState.instance.strumLine.y);
			babyArrow.ID = i;

			var event = PlayState.instance.scripts.event("onStrumCreation", EventManager.get(StrumCreationEvent).recycle(babyArrow, PlayState.instance.strumLines.members.indexOf(this), i));

			if (!event.cancelled) {
				babyArrow.frames = Paths.getFrames(event.sprite);
				babyArrow.animation.addByPrefix('green', 'arrowUP');
				babyArrow.animation.addByPrefix('blue', 'arrowDOWN');
				babyArrow.animation.addByPrefix('purple', 'arrowLEFT');
				babyArrow.animation.addByPrefix('red', 'arrowRIGHT');

				babyArrow.antialiasing = true;
				babyArrow.setGraphicSize(Std.int(babyArrow.width * 0.7));

				switch (babyArrow.ID % 4)
				{
					case 0:
						babyArrow.animation.addByPrefix('static', 'arrowLEFT');
						babyArrow.animation.addByPrefix('pressed', 'left press', 24, false);
						babyArrow.animation.addByPrefix('confirm', 'left confirm', 24, false);
					case 1:
						babyArrow.animation.addByPrefix('static', 'arrowDOWN');
						babyArrow.animation.addByPrefix('pressed', 'down press', 24, false);
						babyArrow.animation.addByPrefix('confirm', 'down confirm', 24, false);
					case 2:
						babyArrow.animation.addByPrefix('static', 'arrowUP');
						babyArrow.animation.addByPrefix('pressed', 'up press', 24, false);
						babyArrow.animation.addByPrefix('confirm', 'up confirm', 24, false);
					case 3:
						babyArrow.animation.addByPrefix('static', 'arrowRIGHT');
						babyArrow.animation.addByPrefix('pressed', 'right press', 24, false);
						babyArrow.animation.addByPrefix('confirm', 'right confirm', 24, false);
				}
			}

			babyArrow.cpu = cpu;
			babyArrow.updateHitbox();
			babyArrow.scrollFactor.set();

			if (event.__doAnimation)
			{
				babyArrow.y -= 10;
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {y: babyArrow.y + 10, alpha: 1}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
			}

			add(babyArrow);

			babyArrow.playAnim('static');
		}
	}

	/**
	 * Deletes a note from this strumline.
	 * @param note Note to delete
	 */
	public function deleteNote(note:Note) {
		if (note == null) return;
		var event:SimpleNoteEvent = EventManager.get(SimpleNoteEvent).recycle(note);
		onNoteDelete.dispatch(event);
		if (!event.cancelled) {
			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
	}

	/**
	 * SETTERS & GETTERS
	 */
	#if REGION
	private inline function set_cpu(b:Bool):Bool {
		for(s in members)
			if (s != null)
				s.cpu = b;
		return cpu = b;
	}
	#end
}