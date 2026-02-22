package mods.compat;
using StringTools;

/**
 * CodenameXmlConverter
 * ─────────────────────────────────────────────────────────────────────────────
 * Parses Codename Engine's XML character format into Cool Engine CharacterData.
 *
 * ── Codename character XML format ────────────────────────────────────────────
 *
 *  <character x="0" y="0" flip_x="false" healthIcon="bf"
 *             healthbar_colors="49,176,209" antialiasing="true"
 *             scale="1" sing_duration="6.1">
 *
 *    <asset path="characters/BOYFRIEND" scale="1"/>
 *
 *    <camera x="0" y="0"/>
 *
 *    <animations>
 *      <anim name="idle"      anim="BF idle dance"   fps="24" loop="false" x="0"   y="0"/>
 *      <anim name="singLEFT"  anim="BF NOTE LEFT0"   fps="24" loop="false" x="-5"  y="27"/>
 *      <anim name="singDOWN"  anim="BF NOTE DOWN0"   fps="24" loop="false" x="0"   y="-20"/>
 *      <anim name="singUP"    anim="BF NOTE UP0"     fps="24" loop="false" x="-29" y="27"/>
 *      <anim name="singRIGHT" anim="BF NOTE RIGHT0"  fps="24" loop="false" x="-38" y="-7"/>
 *      <!-- Some chars have indices:  <anim name="idle" ... indices="0,1,2,3"/> -->
 *    </animations>
 *
 *  </character>
 *
 * ── Notes ────────────────────────────────────────────────────────────────────
 *  - Haxe's built-in Xml class is used — no external library needed.
 *  - "anim" attribute in <anim> is the XML prefix (same as Psych's "name").
 *  - "name" attribute in <anim> is the internal anim name (same as Psych's "anim").
 *  - healthbar_colors is a comma-separated "R,G,B" string.
 */
class CodenameXmlConverter
{
	/**
	 * Parses a Codename Engine character XML string.
	 * Returns a Dynamic compatible with Cool Engine's CharacterData.
	 */
	public static function convertCharacter(xmlContent:String, charName:String):Dynamic
	{
		trace('[CodenameXmlConverter] Parsing XML for "$charName"...');

		var root:Xml = null;
		try
		{
			root = Xml.parse(xmlContent).firstElement();
		}
		catch (e:Dynamic)
		{
			trace('[CodenameXmlConverter] XML parse error: $e');
			return _fallback(charName);
		}

		if (root == null)
		{
			trace('[CodenameXmlConverter] Empty XML for "$charName"');
			return _fallback(charName);
		}

		// ── Root attributes ───────────────────────────────────────────────────
		final flipX         = root.get('flip_x')       == 'true';
		final antialiasing  = root.get('antialiasing') != 'false'; // default true
		final scale         = _parseFloat(root.get('scale'), 1.0);
		final healthIcon    = root.get('healthIcon') ?? root.get('health_icon') ?? charName;

		// healthbar_colors="R,G,B"
		var healthBarColor = '#31B0D1';
		final colorsStr = root.get('healthbar_colors') ?? root.get('healthbar_color') ?? '';
		if (colorsStr != '')
		{
			final parts = colorsStr.split(',');
			if (parts.length >= 3)
			{
				final r = Std.parseInt(parts[0].trim()) ?? 49;
				final g = Std.parseInt(parts[1].trim()) ?? 176;
				final b = Std.parseInt(parts[2].trim()) ?? 209;
				healthBarColor = '#' + _hex2(r) + _hex2(g) + _hex2(b);
			}
		}

		// ── <asset> child ─────────────────────────────────────────────────────
		var assetPath = 'characters/$charName';
		var assetScale = scale;
		final assetNode = _child(root, 'asset');
		if (assetNode != null)
		{
			final p = assetNode.get('path') ?? assetNode.get('src') ?? '';
			if (p != '') assetPath = p;
			assetScale = _parseFloat(assetNode.get('scale'), scale);
		}
		// Strip leading "characters/" prefix — Cool adds it via Paths
		if (assetPath.startsWith('characters/'))
			assetPath = assetPath.substr('characters/'.length);

		// ── <camera> child ────────────────────────────────────────────────────
		var camX = 0.0;
		var camY = 0.0;
		final camNode = _child(root, 'camera');
		if (camNode != null)
		{
			camX = _parseFloat(camNode.get('x'), 0.0);
			camY = _parseFloat(camNode.get('y'), 0.0);
		}

		// ── <animations> → <anim> children ───────────────────────────────────
		final anims:Array<Dynamic> = [];
		final animsNode = _child(root, 'animations');
		if (animsNode != null)
		{
			for (node in animsNode)
			{
				if (node.nodeType != Xml.Element) continue;
				if (node.nodeName.toLowerCase() != 'anim') continue;

				final animName   = node.get('name')   ?? 'idle';
				final animPrefix = node.get('anim')   ?? node.get('prefix') ?? animName;
				final fps        = _parseFloat(node.get('fps') ?? node.get('framerate'), 24.0);
				final loop       = node.get('loop') == 'true' || node.get('looped') == 'true';
				final offsetX    = _parseFloat(node.get('x') ?? node.get('offsetX'), 0.0);
				final offsetY    = _parseFloat(node.get('y') ?? node.get('offsetY'), 0.0);

				// Indices: comma-separated string "0,1,2,3"
				var indices:Array<Int> = null;
				final idxStr = node.get('indices') ?? '';
				if (idxStr != '')
				{
					final parts = idxStr.split(',');
					indices = [for (p in parts) { final n = Std.parseInt(p.trim()); n ?? 0; }];
					if (indices.length == 0) indices = null;
				}

				anims.push({
					name:      animName,
					prefix:    animPrefix,
					framerate: fps,
					looped:    loop,
					offsetX:   offsetX,
					offsetY:   offsetY,
					indices:   indices
				});
			}
		}

		final result:Dynamic = {
			path:           assetPath,
			animations:     anims,
			isPlayer:       false,
			antialiasing:   antialiasing,
			scale:          assetScale,
			flipX:          flipX,
			healthIcon:     healthIcon,
			healthBarColor: healthBarColor,
			cameraOffset:   [camX, camY]
		};

		trace('[CodenameXmlConverter] Done. Anims: ${anims.length}');
		return result;
	}

	// ─── Helpers ─────────────────────────────────────────────────────────────

	static function _child(parent:Xml, tag:String):Null<Xml>
	{
		for (node in parent)
		{
			if (node.nodeType == Xml.Element && node.nodeName.toLowerCase() == tag.toLowerCase())
				return node;
		}
		return null;
	}

	static function _parseFloat(s:String, def:Float):Float
	{
		if (s == null || s == '') return def;
		final f = Std.parseFloat(s);
		return Math.isNaN(f) ? def : f;
	}

	static function _hex2(n:Int):String
	{
		final h = StringTools.hex(n & 0xFF, 2);
		return h.length < 2 ? '0$h' : h;
	}

	static function _fallback(charName:String):Dynamic
	{
		return {
			path:           charName,
			animations:     [],
			isPlayer:       false,
			antialiasing:   true,
			scale:          1.0,
			flipX:          false,
			healthIcon:     charName,
			healthBarColor: '#31B0D1',
			cameraOffset:   [0.0, 0.0]
		};
	}
}
