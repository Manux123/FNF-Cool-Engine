package modding;

class ModPaths {
    public static function getScript(file:String) {
		return 'mods/scripts/$file.hx';
	}

	public static function getSongScript(song:String) {
		trace('[SCRIPTING LOADER] Loading : ' + song);
		return 'mods/data/$song/Modchart.hx';

	}
}