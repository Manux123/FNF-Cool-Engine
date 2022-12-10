package modding;

class ModPaths {
    public static function getScript(file:String) {
		return 'mods/scripts/$file.hx';
	}

	public static function getSongScript(song:String) {
		trace('[SCRIPTING LOADER] Loading : ' + song);
		return 'mods/data/$song/Modchart.hx';

	}

	public static function getImage(key:String) {
		return 'mods/images/$key';
	}

	public static function getDataFile(key:String, ender:String) {
		return 'mods/data/$key.$ender';
	}


	
}
