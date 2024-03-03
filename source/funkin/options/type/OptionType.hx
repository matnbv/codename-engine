package funkin.options.type;

import funkin.system.Controls;
import flixel.group.FlxSpriteGroup;
import funkin.options.OptionsScreen;

class OptionType extends FlxSpriteGroup {
    public var controls(get, null):Controls;
    public var selected:Bool = false;
    public var desc:String;

    public function new(desc:String) {
        super();
        this.desc = desc;
    }

    private function get_controls() {return PlayerSettings.player1.controls;}

    public function onSelect() {

    }

    public override function update(elapsed:Float) {
        super.update(elapsed);
        alpha = (selected ? 1 : 0.6);
    }
}
    