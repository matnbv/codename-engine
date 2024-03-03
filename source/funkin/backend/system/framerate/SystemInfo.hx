package funkin.backend.system.framerate;

import funkin.backend.utils.native.HiddenProcess;
import funkin.backend.utils.MemoryUtil;
import funkin.backend.system.Logs;

using StringTools;

class SystemInfo extends FramerateCategory {
	public static var osInfo:String = "Unknown";
	public static var gpuName:String = "Unknown";
	public static var vRAM:String = "Unknown";
	public static var cpuName:String = "Unknown";
	public static var totalMem:String = "Unknown";
	public static var memType:String = "Unknown";

	static var __formattedSysText:String = "";

	public static inline function init() {
		if (lime.system.System.platformLabel != null && lime.system.System.platformLabel != "" && lime.system.System.platformVersion != null && lime.system.System.platformVersion != "")
			osInfo = '${lime.system.System.platformLabel.replace(lime.system.System.platformVersion, "").trim()} ${lime.system.System.platformVersion}';
		else 
			Logs.trace('Unable to grab OS Label', ERROR, RED);

		try {
			#if windows
			var process = new HiddenProcess("wmic", ["cpu", "get", "name"]);
			if (process.exitCode() == 0) cpuName = process.stdout.readAll().toString().trim().split("\n")[1].trim();
			#elseif mac
			var process = new HiddenProcess("sysctl -a | grep brand_string");
			if (process.exitCode() == 0) cpuName = process.stdout.readAll().toString().trim().split(":")[1].trim();
			#elseif linux
			var process = new HiddenProcess("cat", ["/proc/cpuinfo"]);
			if (process.exitCode() != 0) throw 'Could not fetch CPU information';

			for (line in  process.stdout.readAll().toString().split("\n")) {
				if (line.indexOf("model name") == 0) {
					cpuName = line.substring(line.indexOf(":") + 2);
					break;
				}
			}
			#end
		} catch (e) {
			Logs.trace('Unable to grab CPU Name: $e', ERROR, RED);
		}


		@:privateAccess {
			if (flixel.FlxG.stage.context3D != null && flixel.FlxG.stage.context3D.gl != null) {
				gpuName = Std.string(flixel.FlxG.stage.context3D.gl.getParameter(flixel.FlxG.stage.context3D.gl.RENDERER)).split("/")[0].trim();

				var vRAMBytes:UInt = cast(flixel.FlxG.stage.context3D.gl.getParameter(openfl.display3D.Context3D.__glMemoryTotalAvailable), UInt);
				if (vRAMBytes == 1000 || vRAMBytes <= 0)
					Logs.trace('Unable to grab GPU VRAM', ERROR, RED);
				else
					vRAM = CoolUtil.getSizeString(vRAMBytes * 1000);
			} else 
				Logs.trace('Unable to grab GPU Info', ERROR, RED);
		}

		#if cpp
		totalMem = Std.string(MemoryUtil.getTotalMem() / 1024) + " GB";
		#else 
		Logs.trace('Unable to grab RAM Amount', ERROR, RED);
		#end

		try {
			memType = MemoryUtil.getMemType();
		} catch (e) {
			Logs.trace('Unable to grab RAM Type: $e', ERROR, RED);
		}
		formatSysInfo();
	}

	static function formatSysInfo() {
		if (osInfo != "Unknown") __formattedSysText = 'System: $osInfo';
		if (cpuName != "Unknown") __formattedSysText += '\nCPU: ${cpuName} ${openfl.system.Capabilities.cpuArchitecture} ${(openfl.system.Capabilities.supports64BitProcesses ? '64-Bit' : '32-Bit')}';
		if (gpuName != cpuName && (gpuName != "Unknown" && vRAM != "Unknown")) __formattedSysText += '\nGPU: ${gpuName} | VRAM: ${vRAM}'; // 1000 bytes of vram (apus)
		if (totalMem != "Unknown" && memType != "Unknown") __formattedSysText += '\nTotal MEM: ${totalMem} $memType';
	}

	public function new() {
		super("System Info");
	}

	public override function __enterFrame(t:Int) {
		if (alpha <= 0.05) return;

		_text = __formattedSysText;
		_text += '${__formattedSysText == "" ? "" : "\n"}Garbage Collector: ${MemoryUtil.disableCount > 0 ? "OFF" : "ON"} (${MemoryUtil.disableCount})';

		this.text.text = _text;
		super.__enterFrame(t);
	}
}