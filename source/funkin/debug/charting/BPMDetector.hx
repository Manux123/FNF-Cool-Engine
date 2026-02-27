package funkin.debug.charting;

import openfl.media.Sound;
import openfl.utils.ByteArray;

/**
 * Detecta el BPM de un Sound de OpenFL usando análisis de energía y autocorrelación.
 * También extrae datos de waveform para visualización.
 */
class BPMDetector
{
	/**
	 * Extrae muestras de audio desde un Sound de OpenFL sin usar Sound.extract()
	 * (que fue eliminado en versiones modernas de OpenFL).
	 * Accede al buffer interno de Lime directamente.
	 *
	 * @return Número de muestras estéreo extraídas, o 0 si falla.
	 */
	static function _extractBytes(sound:Sound, bytes:ByteArray, maxSamples:Int):Int
	{
		try
		{
			#if (lime)
			@:privateAccess
			final buffer = sound.__buffer;
			if (buffer == null) return 0;

			final data = buffer.data;
			if (data == null) return 0;

			// Lime stores audio as raw bytes. Typical format: 16-bit signed stereo @ 44100 Hz
			// 1 stereo sample = 2 channels × 2 bytes = 4 bytes
			final bytesPerSample:Int = 4;
			final totalSamples:Int = Std.int(data.length / bytesPerSample);
			final samplesToRead:Int = Std.int(Math.min(totalSamples, maxSamples));

			bytes.length = samplesToRead * 8; // We write as 2×Float32 (8 bytes/sample)
			bytes.position = 0;

			// Scale factor for 16-bit signed: divide by 32768
			final scale:Float = 1.0 / 32768.0;

			for (i in 0...samplesToRead)
			{
				final offset:Int = i * bytesPerSample;
				// Little-endian 16-bit signed
				final lRaw:Int = (data[offset] & 0xFF) | ((data[offset + 1] & 0xFF) << 8);
				final rRaw:Int = (data[offset + 2] & 0xFF) | ((data[offset + 3] & 0xFF) << 8);
				// Sign-extend
				final l:Float = (lRaw > 32767 ? lRaw - 65536 : lRaw) * scale;
				final r:Float = (rRaw > 32767 ? rRaw - 65536 : rRaw) * scale;
				bytes.writeFloat(l);
				bytes.writeFloat(r);
			}

			bytes.position = 0;
			return samplesToRead;
			#else
			return 0;
			#end
		}
		catch (e:Dynamic)
		{
			trace('[BPMDetector] _extractBytes error: $e');
			return 0;
		}
	}

	/**
	 * Detecta el BPM de un Sound extrayendo muestras de audio.
	 * Usa análisis de energía + autocorrelación sobre la función de onset.
	 *
	 * @param sound   El openfl.media.Sound a analizar (null → devuelve -1)
	 * @param minBPM  Mínimo BPM válido (default 60)
	 * @param maxBPM  Máximo BPM válido (default 200)
	 * @return BPM detectado redondeado a 0.5, o -1 si falla
	 */
	public static function detect(sound:Sound, minBPM:Float = 60, maxBPM:Float = 200):Float
	{
		if (sound == null)
			return -1;

		try
		{
			final sampleRate:Int = 44100;

			// Analizar hasta 45 segundos (suficiente para patrón rítmico)
			final maxSamples:Int = sampleRate * 45;

			var bytes:ByteArray = new ByteArray();
			final extracted:Int = _extractBytes(sound, bytes, maxSamples);

			if (extracted <= 0)
				return -1;

			// --- Convertir a mono (L+R)/2 ---
			bytes.position = 0;
			var mono:Array<Float> = [];
			mono.resize(extracted);

			for (i in 0...extracted)
			{
				var l:Float = bytes.readFloat();
				var r:Float = bytes.readFloat();
				mono[i] = (l + r) * 0.5;
			}

			// --- Energía por ventana ---
			final windowSize:Int = 1024;
			final hopSize:Int = 512;
			var energies:Array<Float> = [];

			var i:Int = 0;
			while (i + windowSize < mono.length)
			{
				var energy:Float = 0.0;
				for (j in i...i + windowSize)
					energy += mono[j] * mono[j];
				energies.push(energy / windowSize);
				i += hopSize;
			}

			if (energies.length < 4)
				return -1;

			// --- Función de onset (half-wave rectified flux) ---
			var onsets:Array<Float> = [];
			for (k in 1...energies.length)
			{
				var diff = energies[k] - energies[k - 1];
				onsets.push(diff > 0 ? diff : 0.0);
			}

			// Normalizar
			var maxOnset:Float = 0.0;
			for (o in onsets)
				if (o > maxOnset) maxOnset = o;

			if (maxOnset <= 0.0)
				return -1;

			for (k in 0...onsets.length)
				onsets[k] /= maxOnset;

			// --- Autocorrelación sobre onset para encontrar período dominante ---
			final hopSeconds:Float = hopSize / sampleRate;
			final minLag:Int = Std.int(Math.max(1, Math.round((60.0 / maxBPM) / hopSeconds)));
			var maxLag:Int  = Math.round((60.0 / minBPM) / hopSeconds);

			if (maxLag >= onsets.length)
				maxLag = onsets.length - 1;

			if (minLag >= maxLag)
				return -1;

			var bestLag:Int   = minLag;
			var bestCorr:Float = -1.0;

			for (lag in minLag...maxLag + 1)
			{
				var corr:Float = 0.0;
				final n:Int = onsets.length - lag;
				if (n <= 0) continue;

				for (k in 0...n)
					corr += onsets[k] * onsets[k + lag];

				corr /= n;

				if (corr > bestCorr)
				{
					bestCorr = corr;
					bestLag  = lag;
				}
			}

			final beatPeriodSeconds:Float = bestLag * hopSeconds;
			var detectedBPM:Float = 60.0 / beatPeriodSeconds;

			// Redondear al 0.5 más cercano
			detectedBPM = Math.round(detectedBPM * 2.0) / 2.0;

			// Validar rango
			if (detectedBPM < minBPM || detectedBPM > maxBPM)
				return -1;

			return detectedBPM;
		}
		catch (e:Dynamic)
		{
			trace('[BPMDetector] detect() error: $e');
			return -1;
		}
	}

	/**
	 * Extrae valores de amplitud normalizados [0..1] para dibujar la waveform.
	 *
	 * @param sound       Sound de OpenFL
	 * @param resolution  Número de "bins" horizontales (ancho en píxeles)
	 * @param maxSeconds  Segundos máximos a analizar (default 90)
	 * @return Array<Float> con `resolution` valores entre 0 y 1
	 */
	public static function extractWaveform(sound:Sound, resolution:Int = 512, maxSeconds:Int = 90):Array<Float>
	{
		var result:Array<Float> = [];
		result.resize(resolution);
		for (i in 0...resolution) result[i] = 0.0;

		if (sound == null || resolution <= 0)
			return result;

		try
		{
			final sampleRate:Int = 44100;
			final maxSamples:Int = sampleRate * maxSeconds;

			var bytes:ByteArray = new ByteArray();
			final extracted:Int = _extractBytes(sound, bytes, maxSamples);

			if (extracted <= 0)
				return result;

			final samplesPerBin:Int = Std.int(Math.max(1, extracted / resolution));
			var maxVal:Float = 0.0;
			var bins:Array<Float> = [];
			bins.resize(resolution);

			for (bin in 0...resolution)
			{
				var sum:Float = 0.0;
				var count:Int = 0;
				final startSample:Int = bin * samplesPerBin;
				final endSample:Int   = Std.int(Math.min(extracted, startSample + samplesPerBin));

				// Leer desde ByteArray: cada muestra = 4 bytes L + 4 bytes R
				bytes.position = startSample * 8;

				for (s in startSample...endSample)
				{
					if (bytes.bytesAvailable < 8) break;
					var l:Float = bytes.readFloat();
					var r:Float = bytes.readFloat();
					var val:Float = Math.abs((l + r) * 0.5);
					sum += val;
					count++;
				}

				var avg:Float = count > 0 ? sum / count : 0.0;
				bins[bin] = avg;
				if (avg > maxVal) maxVal = avg;
			}

			// Normalizar
			if (maxVal > 0.0)
			{
				for (i in 0...bins.length)
					result[i] = bins[i] / maxVal;
			}

			return result;
		}
		catch (e:Dynamic)
		{
			trace('[BPMDetector] extractWaveform() error: $e');
			return result;
		}
	}
}
