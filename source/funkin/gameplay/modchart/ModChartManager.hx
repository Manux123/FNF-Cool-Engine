package funkin.gameplay.modchart;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import funkin.gameplay.objects.StrumsGroup;
import funkin.gameplay.modchart.ModChartEvent;
import haxe.Json;

using StringTools;

// ─── Estado interno por strum ─────────────────────────────────────────────────

typedef StrumState =
{
    /** Posición base (la que pusiste en PlayState según scroll mode) */
    var baseX    : Float;
    var baseY    : Float;

    /** Offsets aplicados por el modchart */
    var offsetX  : Float;
    var offsetY  : Float;

    /** Posición absoluta (cuando un evento usa SET_ABS_X/Y, sobreescribe base+offset) */
    var absX     : Null<Float>;
    var absY     : Null<Float>;

    /** Ángulo acumulado */
    var angle    : Float;

    /** Rotación continua (deg/beat, se acumula cada beat) */
    var spinRate : Float;

    /** Alpha */
    var alpha    : Float;

    /** Escala */
    var scaleX   : Float;
    var scaleY   : Float;

    /** Visibilidad */
    var visible  : Bool;
}

// ─── Evento en ejecución ──────────────────────────────────────────────────────

typedef ActiveTween =
{
    var event     : ModChartEvent;
    var startBeat : Float;
    var startVal  : Float;   // valor del strum al inicio del tween
    var groupId   : String;
    var strumIdx  : Int;
}

// ─── Manager principal ────────────────────────────────────────────────────────

class ModChartManager
{
    // ── Datos ──────────────────────────────────────────────────────────────────
    public var data:ModChartData;

    // ── Grupos de strums ───────────────────────────────────────────────────────
    private var strumsGroups:Array<StrumsGroup>;

    /**
     * Estado de cada strum:  states[groupId][strumIdx 0-3]
     */
    private var states:Map<String, Array<StrumState>> = new Map();

    // ── Eventos pendientes (aún no disparados) ─────────────────────────────────
    private var pending:Array<ModChartEvent> = [];

    /**
     * Índice del próximo evento pendiente.
     * Reemplaza pending.shift() (O(n)) por un avance de puntero O(1).
     */
    private var _pendingIdx:Int = 0;

    // ── Tweens activos (en interpolación) ─────────────────────────────────────
    private var activeTweens:Array<ActiveTween> = [];

    /**
     * Array reutilizable para tweens terminados — evita new Array() cada frame.
     */
    private var _finishedTweens:Array<ActiveTween> = [];

    // ── Tiempo actual ──────────────────────────────────────────────────────────
    private var currentBeat:Float = 0;
    private var songPosition:Float = 0;

    // ── Flags ──────────────────────────────────────────────────────────────────
    public var enabled:Bool = true;

    // ── Singleton cómodo ──────────────────────────────────────────────────────
    public static var instance:ModChartManager = null;

    // ─────────────────────────────────────────────────────────────────────────

    public function new(strumsGroups:Array<StrumsGroup>)
    {
        instance = this;
        this.strumsGroups = strumsGroups;

        // Datos vacíos por defecto
        data = {
            name    : "New ModChart",
            song    : "",
            version : "1.0",
            events  : []
        };

        captureBasePositions();
        trace('[ModChartManager] Inicializado con ${strumsGroups.length} grupos de strums');
    }

    // ─── Captura de posiciones base ────────────────────────────────────────────

    /**
     * Reemplaza los StrumsGroups internos por unos nuevos y recaptura posiciones.
     * Úsalo desde el editor para redirigir applyAllStates() a los strums propios
     * del editor en vez de los de PlayState (que ya habrán sido destruidos).
     */
    public function replaceStrumsGroups(newGroups:Array<StrumsGroup>):Void
    {
        this.strumsGroups = newGroups;
        captureBasePositions();
        trace('[ModChartManager] StrumsGroups reemplazados: ${newGroups.length} grupos');
    }

    /**
     * Captura la posición ACTUAL de cada strum como posición base.
     * Llamar después de que PlayState haya colocado todos los strums.
     * Funciona en cualquier modo de scroll porque lee las posiciones reales.
     */
    public function captureBasePositions():Void
    {
        states.clear();

        for (group in strumsGroups)
        {
            var arr:Array<StrumState> = [];

            for (i in 0...4)
            {
                var spr = group.getStrum(i);
                if (spr == null)
                {
                    arr.push(makeDefaultState(0, 0));
                    continue;
                }

                var st:StrumState = {
                    baseX   : spr.x,
                    baseY   : spr.y,
                    offsetX : 0,
                    offsetY : 0,
                    absX    : null,
                    absY    : null,
                    angle   : 0,
                    spinRate: 0,
                    alpha   : 1,
                    scaleX  : spr.scale.x,
                    scaleY  : spr.scale.y,
                    visible : spr.visible
                };

                arr.push(st);
            }

            states.set(group.id, arr);
        }

        trace('[ModChartManager] Posiciones base capturadas para ${strumsGroups.length} grupos');
    }

    private function makeDefaultState(bx:Float, by:Float):StrumState
    {
        return {
            baseX   : bx,
            baseY   : by,
            offsetX : 0,
            offsetY : 0,
            absX    : null,
            absY    : null,
            angle   : 0,
            spinRate: 0,
            alpha   : 1,
            scaleX  : 0.7,
            scaleY  : 0.7,
            visible : true
        };
    }

    // ─── Carga/guardado ───────────────────────────────────────────────────────

    /** Carga el modchart de una canción desde assets/modcharts/<song>.json */
    public function loadFromFile(songName:String):Bool
    {
        var song = songName.toLowerCase();

        // ── Función helper: buscar en todas las fuentes posibles ─────────────
        // Orden de prioridad: mod activo → otros mods habilitados → assets base
        var searchPaths:Array<String> = [];

        // 1. Mod activo (máxima prioridad)
        #if sys
        var activeMod = mods.ModManager.activeMod;
        if (activeMod != null)
        {
            searchPaths.push('mods/$activeMod/songs/${song}/modchart.hx');
            searchPaths.push('mods/$activeMod/songs/${song}/modchart.json');
        }

        // 2. Todos los mods habilitados (en orden)
        for (mod in mods.ModManager.installedMods)
        {
            if (!mod.enabled) continue;
            if (mod.id == activeMod) continue; // ya añadido arriba
            searchPaths.push('mods/${mod.id}/songs/${song}/modchart.hx');
            searchPaths.push('mods/${mod.id}/songs/${song}/modchart.json');
        }
        #end

        // 3. Assets base
        searchPaths.push('assets/songs/${song}/modchart.hx');
        searchPaths.push('assets/data/modcharts/${song}.hx');
        searchPaths.push('assets/songs/${song}/modchart.json');
        searchPaths.push('assets/data/modcharts/${song}.json');

        // ── Buscar y cargar ──────────────────────────────────────────────────
        for (p in searchPaths)
        {
            #if sys
            var exists = sys.FileSystem.exists(p);
            #else
            var exists = openfl.Assets.exists(p);
            #end

            if (!exists) continue;

            if (p.endsWith('.hx'))
            {
                var result = loadFromHScript(p, songName);
                if (result) return true;
            }
            else if (p.endsWith('.json'))
            {
                try
                {
                    var txt = #if sys sys.io.File.getContent(p) #else openfl.Assets.getText(p) #end;
                    var loaded:ModChartData = Json.parse(txt);
                    data = loaded;
                    data.events.sort((a, b) -> a.beat < b.beat ? -1 : (a.beat > b.beat ? 1 : 0));
                    pending = data.events.copy();
                    trace('[ModChartManager] Modchart JSON cargado desde "$p" (${data.events.length} eventos)');
                    return true;
                }
                catch (e:Dynamic)
                {
                    trace('[ModChartManager] ERROR al cargar modchart JSON "$p": $e');
                }
            }
        }

        trace('[ModChartManager] No hay modchart para "$songName"');
        return false;
    }

    /**
     * Carga un modchart desde un archivo HScript.
     *
     * El script puede usar estas funciones:
     *   onCreate()             — se llama al cargar el script
     *   onBeatHit(beat:Int)    — en cada beat
     *   onStepHit(step:Int)    — en cada step
     *   onUpdate(pos:Float)    — cada frame (songPosition en ms)
     *   onNoteHit(note)        — cuando se golpea una nota
     *
     * Y estas APIs de modchart (disponibles como variables globales):
     *   modChart.addEventSimple(beat, target, strumIdx, type, value, dur, ease)
     *   modChart.clearEvents()
     *   MOVE_X / MOVE_Y / ANGLE / ALPHA / SCALE / SPIN / RESET / VISIBLE / SET_ABS_X / SET_ABS_Y
     *   LINEAR / QUAD_IN / QUAD_OUT / QUAD_IN_OUT / CUBE_IN / CUBE_OUT / ELASTIC_OUT / BOUNCE_OUT ...
     *
     * Ejemplo de modchart HScript:
     *   function onCreate() {
     *     // Rotar todos los strums del jugador 360° en 4 beats a partir del beat 8
     *     modChart.addEventSimple(8, "player", -1, ANGLE, 360, 4, SINE_IN_OUT);
     *     // Hacer bounce a un strum individual
     *     modChart.addEventSimple(16, "cpu", 0, MOVE_Y, -100, 2, BOUNCE_OUT);
     *   }
     *   function onBeatHit(beat) {
     *     if (beat % 4 == 0)
     *       modChart.addEventSimple(beat, "all", -1, SCALE, 1.2, 0.5, ELASTIC_OUT);
     *   }
     */
    public function loadFromHScript(path:String, songName:String = ''):Bool
    {
        #if HSCRIPT_ALLOWED
        try
        {
            var src = #if sys sys.io.File.getContent(path) #else openfl.Assets.getText(path) #end;
            if (src == null || src.length == 0) return false;

            var parser = new hscript.Parser();
            parser.allowTypes = true;
            #if (hscript >= "2.5.0")
            try { parser.allowMetadata = true; } catch(_:Dynamic) {}
            #end
            var prog = parser.parseString(src);
            var interp = new hscript.Interp();

            // ── Exponer constantes de ModEventType ──────────────────────────
            interp.variables.set('MOVE_X',    ModEventType.MOVE_X);
            interp.variables.set('MOVE_Y',    ModEventType.MOVE_Y);
            interp.variables.set('ANGLE',     ModEventType.ANGLE);
            interp.variables.set('ALPHA',     ModEventType.ALPHA);
            interp.variables.set('SCALE',     ModEventType.SCALE);
            interp.variables.set('SCALE_X',   ModEventType.SCALE_X);
            interp.variables.set('SCALE_Y',   ModEventType.SCALE_Y);
            interp.variables.set('SPIN',      ModEventType.SPIN);
            interp.variables.set('RESET',     ModEventType.RESET);
            interp.variables.set('SET_ABS_X', ModEventType.SET_ABS_X);
            interp.variables.set('SET_ABS_Y', ModEventType.SET_ABS_Y);
            interp.variables.set('VISIBLE',   ModEventType.VISIBLE);

            // ── Exponer constantes de ModEase ────────────────────────────────
            interp.variables.set('LINEAR',      ModEase.LINEAR);
            interp.variables.set('QUAD_IN',     ModEase.QUAD_IN);
            interp.variables.set('QUAD_OUT',    ModEase.QUAD_OUT);
            interp.variables.set('QUAD_IN_OUT', ModEase.QUAD_IN_OUT);
            interp.variables.set('CUBE_IN',     ModEase.CUBE_IN);
            interp.variables.set('CUBE_OUT',    ModEase.CUBE_OUT);
            interp.variables.set('CUBE_IN_OUT', ModEase.CUBE_IN_OUT);
            interp.variables.set('SINE_IN',     ModEase.SINE_IN);
            interp.variables.set('SINE_OUT',    ModEase.SINE_OUT);
            interp.variables.set('SINE_IN_OUT', ModEase.SINE_IN_OUT);
            interp.variables.set('ELASTIC_IN',  ModEase.ELASTIC_IN);
            interp.variables.set('ELASTIC_OUT', ModEase.ELASTIC_OUT);
            interp.variables.set('BOUNCE_OUT',  ModEase.BOUNCE_OUT);
            interp.variables.set('BACK_IN',     ModEase.BACK_IN);
            interp.variables.set('BACK_OUT',    ModEase.BACK_OUT);
            interp.variables.set('INSTANT',     ModEase.INSTANT);

            // ── Exponer API del modchart ─────────────────────────────────────
            interp.variables.set('modChart', this);
            interp.variables.set('song', songName);

            // Ejecutar el programa (define funciones)
            interp.execute(prog);

            // Guardar el intérprete para callbacks en tiempo real
            _hscriptInterp = interp;

            // Llamar onCreate() si existe
            if (interp.variables.exists('onCreate'))
            {
                try { Reflect.callMethod(null, interp.variables.get('onCreate'), []); }
                catch (e:Dynamic) { trace('[ModChartManager] Error en onCreate(): $e'); }
            }

            data.events.sort((a, b) -> a.beat < b.beat ? -1 : (a.beat > b.beat ? 1 : 0));
            pending = data.events.copy();

            trace('[ModChartManager] Modchart HScript cargado: "$path" (${data.events.length} eventos pre-generados)');
            return true;
        }
        catch (e:Dynamic)
        {
            trace('[ModChartManager] ERROR al cargar modchart HScript: $e');
            return false;
        }
        #else
        trace('[ModChartManager] HScript no disponible (compilar con -D HSCRIPT_ALLOWED)');
        return false;
        #end
    }

    #if HSCRIPT_ALLOWED
    /** Intérprete HScript para el modchart (null si no hay script activo) */
    private var _hscriptInterp:Null<hscript.Interp> = null;

    /** Llama una función del modchart HScript si existe. */
    private inline function _callHScript(func:String, args:Array<Dynamic>):Void
    {
        if (_hscriptInterp == null) return;
        if (!_hscriptInterp.variables.exists(func)) return;
        try { Reflect.callMethod(null, _hscriptInterp.variables.get(func), args); }
        catch (e:Dynamic) { trace('[ModChartManager] Error en $func(): $e'); }
    }
    #end

    /** Carga modchart desde string JSON (útil para el editor) */
    public function loadFromJson(json:String):Void
    {
        try
        {
            var loaded:ModChartData = Json.parse(json);
            data = loaded;
            data.events.sort((a, b) -> a.beat < b.beat ? -1 : 1);
            resetToStart();
        }
        catch (e:Dynamic)
        {
            trace('[ModChartManager] ERROR parse JSON: $e');
        }
    }

    /** Carga directamente un ModChartData */
    public function loadData(d:ModChartData):Void
    {
        data = d;
        data.events.sort((a, b) -> a.beat < b.beat ? -1 : 1);
        resetToStart();
    }

    /** Serializa el modchart actual a JSON */
    public function toJson():String
        return Json.stringify(data, null, "  ");

    // ─── Control de playback ──────────────────────────────────────────────────

    /**
     * Reinicia todos los estados a posición base y recarga eventos pendientes.
     * Llamar cuando el juego reinicia o se salta a un punto.
     */
    public function resetToStart():Void
    {
        activeTweens = [];

        // Reiniciar estados (mantener baseX/Y, resetear offsets)
        for (group in strumsGroups)
        {
            var arr = states.get(group.id);
            if (arr == null) continue;

            for (i in 0...arr.length)
            {
                var st  = arr[i];
                var spr = group.getStrum(i);
                st.offsetX  = 0;
                st.offsetY  = 0;
                st.absX     = null;
                st.absY     = null;
                st.angle    = 0;
                st.spinRate = 0;
                st.alpha    = 1;
                // Restaurar escala base real (no hardcodeada a 0.7)
                st.scaleX   = (spr != null) ? spr.scale.x : 0.7;
                st.scaleY   = (spr != null) ? spr.scale.y : 0.7;
                st.visible  = true;
            }
        }

        // Re-copiar eventos pendientes a partir del beat actual
        _pendingIdx = 0; pending = [];
        for (ev in data.events)
        {
            if (ev.beat >= currentBeat - 0.01)
                pending.push(ev);
        }

        applyAllStates();
        trace('[ModChartManager] Reset. Eventos pendientes: ${pending.length}');
    }

    /**
     * Salta a un beat específico (para preview del editor).
     * Aplica todos los eventos hasta ese beat instantáneamente.
     */
    public function seekToBeat(beat:Float):Void
    {
        // Resetear estados
        for (group in strumsGroups)
        {
            var arr = states.get(group.id);
            if (arr == null) continue;
            for (i in 0...arr.length)
            {
                var st  = arr[i];
                var spr = group.getStrum(i);
                st.offsetX = 0; st.offsetY = 0;
                st.absX = null; st.absY = null;
                st.angle = 0; st.spinRate = 0;
                st.alpha = 1;
                st.scaleX = (spr != null) ? spr.scale.x : 0.7;
                st.scaleY = (spr != null) ? spr.scale.y : 0.7;
                st.visible = true;
            }
        }

        // Reproducir todos los eventos hasta el beat objetivo
        var simBeat:Float = 0;
        for (ev in data.events)
        {
            if (ev.beat > beat) break;
            // Aplicar instantáneamente (t=1)
            applyEventInstant(ev);
        }

        currentBeat = beat;

        // Preparar pendientes desde este beat
        activeTweens = [];
        _pendingIdx = 0; pending = [];
        for (ev in data.events)
        {
            if (ev.beat >= beat - 0.01)
                pending.push(ev);
        }

        applyAllStates();
    }

    // ─── Update principal ─────────────────────────────────────────────────────

    /**
     * Llamar cada frame desde PlayState.update()
     * Solo requiere Conductor.songPosition — beat/step se calculan internamente.
     * Evita depender de curBeat/curStep, que son 'private' en MusicBeatState
     * y NO son accesibles desde subclases en Haxe (a diferencia de Java).
     */
    public function update(songPos:Float):Void
    {
        if (!enabled) return;

        this.songPosition = songPos;

        // Beat en punto flotante derivado directamente del conductor
        var beatFloat:Float = (funkin.data.Conductor.crochet > 0)
            ? songPos / funkin.data.Conductor.crochet
            : 0.0;

        this.currentBeat = beatFloat;

        // 1. Disparar eventos cuyo beat ya llegó
        fireReadyEvents(beatFloat);

        // 2. Actualizar tweens activos
        updateTweens(beatFloat);

        // 3. Aplicar spin continuo
        applySpins(FlxG.elapsed);

        // 4. Escribir valores en los sprites
        applyAllStates();

        // 5. HScript onUpdate hook (para modcharts que quieran lógica por frame)
        #if HSCRIPT_ALLOWED
        _callHScript('onUpdate', [songPos]);
        #end
    }

    // ── Disparar eventos ────────────────────────────────────────────────────

    private function fireReadyEvents(curBeat:Float):Void
    {
        while (_pendingIdx < pending.length)
        {
            final ev = pending[_pendingIdx];
            if (ev.beat > curBeat) break;

            _pendingIdx++;

            if (ev.type == RESET)
            {
                applyReset(ev);
                continue;
            }

            if (ev.duration <= 0 || ev.ease == INSTANT)
            {
                applyEventInstant(ev);
            }
            else
            {
                // Crear tween para este evento
                final targets = resolveTargets(ev.target, ev.strumIdx);
                for (t in targets)
                {
                    activeTweens.push({
                        event     : ev,
                        startBeat : ev.beat,
                        startVal  : getStateValue(t.groupId, t.strumIdx, ev.type),
                        groupId   : t.groupId,
                        strumIdx  : t.strumIdx
                    });
                }
            }
        }
    }

    // ── Actualizar tweens ───────────────────────────────────────────────────

    private function updateTweens(curBeat:Float):Void
    {
        // Usar _finishedTweens reutilizable — evita new Array cada frame
        _finishedTweens.resize(0);

        for (tw in activeTweens)
        {
            final elapsed = curBeat - tw.startBeat;
            final t       = tw.event.duration > 0 ? elapsed / tw.event.duration : 1.0;
            final eased   = ModChartHelpers.applyEase(tw.event.ease, t);
            final val     = tw.startVal + (tw.event.value - tw.startVal) * eased;

            setStateValue(tw.groupId, tw.strumIdx, tw.event.type, val);

            if (t >= 1.0)
                _finishedTweens.push(tw);
        }

        // Eliminar tweens terminados en una pasada inversa (O(n), no O(n²))
        var i = _finishedTweens.length - 1;
        while (i >= 0)
        {
            final idx = activeTweens.indexOf(_finishedTweens[i]);
            if (idx >= 0) activeTweens.splice(idx, 1);
            i--;
        }
    }

    // ── Spin continuo ───────────────────────────────────────────────────────

    private function applySpins(elapsed:Float):Void
    {
        // beats per second = bpm / 60
        var bps:Float = funkin.data.Conductor.bpm / 60.0;
        for (group in strumsGroups)
        {
            var arr = states.get(group.id);
            if (arr == null) continue;

            for (st in arr)
            {
                if (st.spinRate != 0)
                    st.angle += st.spinRate * elapsed * bps;
            }
        }
    }

    // ── Aplicar estados a sprites ────────────────────────────────────────────

    private function applyAllStates():Void
    {
        for (group in strumsGroups)
        {
            var arr = states.get(group.id);
            if (arr == null) continue;

            for (i in 0...4)
            {
                var spr = group.getStrum(i);
                if (spr == null || i >= arr.length) continue;

                var st = arr[i];

                // Posición
                if (st.absX != null)
                    spr.x = st.absX;
                else
                    spr.x = st.baseX + st.offsetX;

                if (st.absY != null)
                    spr.y = st.absY;
                else
                    spr.y = st.baseY + st.offsetY;

                // Ángulo
                spr.angle = st.angle;

                // Alpha
                spr.alpha = Math.max(0, Math.min(1, st.alpha));

                // Escala
                spr.scale.set(st.scaleX, st.scaleY);

                // Visibilidad
                spr.visible = st.visible;
            }
        }
    }

    // ── Helpers de resolución de targets ────────────────────────────────────

    private function resolveTargets(target:String, strumIdx:Int):Array<{groupId:String, strumIdx:Int}>
    {
        var result:Array<{groupId:String, strumIdx:Int}> = [];

        var groupIds:Array<String> = [];

        if (target == "all")
        {
            for (g in strumsGroups) groupIds.push(g.id);
        }
        else if (target == "player")
        {
            for (g in strumsGroups) if (!g.isCPU) groupIds.push(g.id);
        }
        else if (target == "cpu")
        {
            for (g in strumsGroups) if (g.isCPU) groupIds.push(g.id);
        }
        else
        {
            groupIds.push(target);
        }

        for (gid in groupIds)
        {
            if (strumIdx == -1)
            {
                for (s in 0...4) result.push({ groupId: gid, strumIdx: s });
            }
            else
            {
                result.push({ groupId: gid, strumIdx: strumIdx });
            }
        }

        return result;
    }

    // ── Leer/escribir valor de estado ────────────────────────────────────────

    private function getStateValue(groupId:String, strumIdx:Int, type:ModEventType):Float
    {
        var arr = states.get(groupId);
        if (arr == null || strumIdx < 0 || strumIdx >= arr.length) return 0;
        var st = arr[strumIdx];

        return switch (type)
        {
            case MOVE_X | SET_ABS_X : type == MOVE_X ? st.offsetX : (st.absX != null ? st.absX : st.baseX);
            case MOVE_Y | SET_ABS_Y : type == MOVE_Y ? st.offsetY : (st.absY != null ? st.absY : st.baseY);
            case ANGLE              : st.angle;
            case ALPHA              : st.alpha;
            case SCALE              : st.scaleX;
            case SCALE_X            : st.scaleX;
            case SCALE_Y            : st.scaleY;
            case SPIN               : st.spinRate;
            case VISIBLE            : st.visible ? 1 : 0;
            default                 : 0;
        };
    }

    private function setStateValue(groupId:String, strumIdx:Int, type:ModEventType, value:Float):Void
    {
        var arr = states.get(groupId);
        if (arr == null || strumIdx < 0 || strumIdx >= arr.length) return;
        var st = arr[strumIdx];

        switch (type)
        {
            case MOVE_X    : st.offsetX  = value; st.absX = null;
            case MOVE_Y    : st.offsetY  = value; st.absY = null;
            case SET_ABS_X : st.absX     = value;
            case SET_ABS_Y : st.absY     = value;
            case ANGLE     : st.angle    = value;
            case ALPHA     : st.alpha    = value;
            case SCALE     : st.scaleX   = value; st.scaleY = value;
            case SCALE_X   : st.scaleX   = value;
            case SCALE_Y   : st.scaleY   = value;
            case SPIN      : st.spinRate = value;
            case VISIBLE   : st.visible  = value >= 0.5;
            case RESET     : /* handled separately */
        }
    }

    private function applyEventInstant(ev:ModChartEvent):Void
    {
        var targets = resolveTargets(ev.target, ev.strumIdx);
        for (t in targets)
            setStateValue(t.groupId, t.strumIdx, ev.type, ev.value);
    }

    private function applyReset(ev:ModChartEvent):Void
    {
        var targets = resolveTargets(ev.target, ev.strumIdx);
        for (t in targets)
        {
            var arr = states.get(t.groupId);
            if (arr == null) continue;
            if (t.strumIdx < 0 || t.strumIdx >= arr.length) continue;
            var st  = arr[t.strumIdx];
            // Buscar el sprite para restaurar escala real
            var spr:Dynamic = null;
            for (g in strumsGroups)
                if (g.id == t.groupId) { spr = g.getStrum(t.strumIdx); break; }
            st.offsetX = 0; st.offsetY = 0;
            st.absX = null; st.absY = null;
            st.angle = 0; st.spinRate = 0;
            st.alpha = 1;
            st.scaleX = (spr != null) ? spr.scale.x : 0.7;
            st.scaleY = (spr != null) ? spr.scale.y : 0.7;
            st.visible = true;
        }
    }

    // ─── API pública de scripting ─────────────────────────────────────────────

    /**
     * Agrega un evento en tiempo de ejecución (desde scripts de canción).
     * El evento se integra ordenado en la lista.
     */
    public function addEvent(ev:ModChartEvent):Void
    {
        data.events.push(ev);
        data.events.sort((a, b) -> a.beat < b.beat ? -1 : 1);

        if (ev.beat >= currentBeat - 0.01)
            pending.push(ev);

        pending.sort((a, b) -> a.beat < b.beat ? -1 : 1);
    }

    /** Agrega un evento simple con la API fluida de ModChartHelpers */
    public function addEventSimple(beat:Float, target:String, strumIdx:Int,
                                    type:ModEventType, value:Float,
                                    duration:Float = 0, ease:ModEase = LINEAR):Void
    {
        addEvent(ModChartHelpers.makeEvent(beat, target, strumIdx, type, value, duration, ease));
    }

    /** Borra todos los eventos */
    public function clearEvents():Void
    {
        data.events = [];
        _pendingIdx = 0; pending = [];
        activeTweens = [];
    }

    /** Acceso directo al estado de un strum (para el editor) */
    public function getState(groupId:String, strumIdx:Int):Null<StrumState>
    {
        var arr = states.get(groupId);
        if (arr == null || strumIdx < 0 || strumIdx >= arr.length) return null;
        return arr[strumIdx];
    }

    /** Devuelve la posición visual actual de un strum (para el editor) */
    public function getStrumDisplayPos(groupId:String, strumIdx:Int):{x:Float, y:Float}
    {
        var st = getState(groupId, strumIdx);
        if (st == null) return { x: 0, y: 0 };
        return {
            x : st.absX != null ? st.absX : st.baseX + st.offsetX,
            y : st.absY != null ? st.absY : st.baseY + st.offsetY
        };
    }

    // ─── Beat / Step hooks ────────────────────────────────────────────────────

    /** Llamar desde overrideBeatHit() de PlayState */
    public function onBeatHit(beat:Int):Void
    {
        // El update() ya maneja el timing con curBeat float.
        // Este hook es para efectos instantáneos ligados al beat exacto si se necesitan.
        #if HSCRIPT_ALLOWED
        _callHScript('onBeatHit', [beat]);
        #end
    }

    /** Llamar desde overrideStepHit() de PlayState */
    public function onStepHit(step:Int):Void {
        #if HSCRIPT_ALLOWED
        _callHScript('onStepHit', [step]);
        #end
    }

    // ─── Destructor ───────────────────────────────────────────────────────────

    public function destroy():Void
    {
        activeTweens = [];
        _pendingIdx = 0; pending = [];
        states.clear();
        strumsGroups = null;
        #if HSCRIPT_ALLOWED
        _hscriptInterp = null;
        #end
        instance = null;
    }
}
