package funkin.gameplay.modchart;

/**
 * ============================================================
 *  ModChartEvent.hx  –  Tipos de datos del sistema ModChart
 * ============================================================
 *
 *  Contiene:
 *    • ModEventType  – Enum con todos los tipos de evento
 *    • ModEase       – Easings disponibles
 *    • ModChartEvent – Struct de un evento individual
 *    • ModChartData  – Archivo completo de modchart (JSON-serializable)
 *
 *  Compatibilidad:
 *    • Los valores de posición/ángulo son OFFSETS desde la posición base
 *      del strum (calculada por PlayState según downscroll / middlescroll).
 *    • Así el mismo modchart funciona en upscroll, downscroll y middlescroll
 *      sin ajuste manual.
 */

// ─── Tipos de modificación disponibles ───────────────────────────────────────

enum abstract ModEventType(String) from String to String
{
    /** Desplazamiento horizontal (offset desde posición base) */
    var MOVE_X      = "moveX";
    /** Desplazamiento vertical (offset desde posición base) */
    var MOVE_Y      = "moveY";
    /** Ángulo de rotación en grados */
    var ANGLE       = "angle";
    /** Transparencia 0-1 */
    var ALPHA       = "alpha";
    /** Escala uniforme */
    var SCALE       = "scale";
    /** Escala solo en X */
    var SCALE_X     = "scaleX";
    /** Escala solo en Y */
    var SCALE_Y     = "scaleY";
    /** Rotación continua (grados/beat) */
    var SPIN        = "spin";
    /** Resetea TODOS los offsets del strum a 0 */
    var RESET       = "reset";
    /** Mueve el strum a posición absoluta (ignora base) */
    var SET_ABS_X   = "setAbsX";
    /** Mueve el strum a posición absoluta (ignora base) */
    var SET_ABS_Y   = "setAbsY";
    /** Visibilidad (1 = visible, 0 = oculto) */
    var VISIBLE     = "visible";
}

// ─── Easings ─────────────────────────────────────────────────────────────────

enum abstract ModEase(String) from String to String
{
    var LINEAR       = "linear";
    var QUAD_IN      = "quadIn";
    var QUAD_OUT     = "quadOut";
    var QUAD_IN_OUT  = "quadInOut";
    var CUBE_IN      = "cubeIn";
    var CUBE_OUT     = "cubeOut";
    var CUBE_IN_OUT  = "cubeInOut";
    var SINE_IN      = "sineIn";
    var SINE_OUT     = "sineOut";
    var SINE_IN_OUT  = "sineInOut";
    var ELASTIC_IN   = "elasticIn";
    var ELASTIC_OUT  = "elasticOut";
    var BOUNCE_OUT   = "bounceOut";
    var BACK_IN      = "backIn";
    var BACK_OUT     = "backOut";
    var INSTANT      = "instant";     // Aplica el valor sin interpolación
}

// ─── Evento individual ────────────────────────────────────────────────────────

typedef ModChartEvent =
{
    /** UUID único para este evento (generado al crearlo) */
    var id        : String;

    /**
     * Momento de inicio en BEATS (puede ser fraccionario, ej: 1.5 = beat 1 + 2 steps).
     * Para usar steps, divide: beat = step / stepsPerBeat (normalmente /4).
     */
    var beat      : Float;

    /**
     * Grupo de strums objetivo:
     *   "player" → grupo del jugador
     *   "cpu"    → grupo del CPU
     *   "all"    → todos los grupos
     *   o el id de un StrumsGroup específico
     */
    var target    : String;

    /**
     * Índice de strum dentro del grupo (-1 = todos, 0-3 = individual):
     *   0 = LEFT, 1 = DOWN, 2 = UP, 3 = RIGHT
     */
    var strumIdx  : Int;

    /** Tipo de modificación */
    var type      : ModEventType;

    /** Valor destino (significado depende del tipo) */
    var value     : Float;

    /**
     * Duración de la interpolación en BEATS.
     * 0 o negativo = aplicar instantáneamente (igual que INSTANT ease).
     */
    var duration  : Float;

    /** Easing de la interpolación */
    var ease      : ModEase;

    /** Etiqueta opcional para el editor */
    var label     : String;

    /** Color del bloque en el editor (ARGB hex) */
    var color     : Int;
}

// ─── Archivo completo de modchart ─────────────────────────────────────────────

typedef ModChartData =
{
    /** Nombre del modchart (para mostrar en el editor) */
    var name     : String;

    /** Canción a la que pertenece */
    var song     : String;

    /** Versión del formato */
    var version  : String;

    /** Lista de eventos ordenados por beat */
    var events   : Array<ModChartEvent>;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class ModChartHelpers
{
    static var _uid:Int = 0;

    /** Genera un ID único simple */
    public static function newId():String
        return "ev_" + (++_uid) + "_" + Std.string(Std.random(9999));

    /** Crea un ModChartEvent con valores por defecto */
    public static function makeEvent(beat:Float, target:String, strumIdx:Int,
                                     type:ModEventType, value:Float,
                                     duration:Float = 0.0, ease:ModEase = LINEAR):ModChartEvent
    {
        return {
            id       : newId(),
            beat     : beat,
            target   : target,
            strumIdx : strumIdx,
            type     : type,
            value    : value,
            duration : duration,
            ease     : ease,
            label    : type,
            color    : defaultColor(type)
        };
    }

    /** Color por defecto según tipo */
    public static function defaultColor(type:ModEventType):Int
    {
        return switch (type)
        {
            case MOVE_X     | SET_ABS_X : 0xFF4FC3F7;   // azul claro
            case MOVE_Y     | SET_ABS_Y : 0xFF81C784;   // verde
            case ANGLE      | SPIN      : 0xFFFFB74D;   // naranja
            case ALPHA                  : 0xFFBA68C8;   // morado
            case SCALE | SCALE_X | SCALE_Y: 0xFFFF8A65; // coral
            case VISIBLE                : 0xFFE0E0E0;   // gris
            case RESET                  : 0xFFEF5350;   // rojo
            default                     : 0xFF90CAF9;
        };
    }

    /** Interpola con el ease indicado (t = 0..1) */
    public static function applyEase(ease:ModEase, t:Float):Float
    {
        t = Math.max(0, Math.min(1, t));
        return switch (ease)
        {
            case LINEAR       : t;
            case QUAD_IN      : t * t;
            case QUAD_OUT     : t * (2 - t);
            case QUAD_IN_OUT  : t < .5 ? 2*t*t : -1+(4-2*t)*t;
            case CUBE_IN      : t * t * t;
            case CUBE_OUT     : var t1 = t-1; t1*t1*t1+1;
            case CUBE_IN_OUT  : t < .5 ? 4*t*t*t : (t-1)*(2*t-2)*(2*t-2)+1;
            case SINE_IN      : 1 - Math.cos(t * Math.PI / 2);
            case SINE_OUT     : Math.sin(t * Math.PI / 2);
            case SINE_IN_OUT  : -(Math.cos(Math.PI*t)-1)/2;
            case ELASTIC_IN   :
                if (t == 0 || t == 1) t
                else { var p=0.3; -(Math.pow(2,10*(t-1))*Math.sin(((t-1)-p/4)*(2*Math.PI)/p)); }
            case ELASTIC_OUT  :
                if (t == 0 || t == 1) t
                else { var p=0.3; Math.pow(2,-10*t)*Math.sin((t-p/4)*(2*Math.PI)/p)+1; }
            case BOUNCE_OUT   : bounceOut(t);
            case BACK_IN      : t*t*((1.70158+1)*t - 1.70158);
            case BACK_OUT     : var t1=t-1; t1*t1*((1.70158+1)*t1+1.70158)+1;
            case INSTANT      : 1.0;
            default           : t;
        };
    }

    static function bounceOut(t:Float):Float
    {
        if (t < 1/2.75)     return 7.5625*t*t;
        else if (t < 2/2.75){ t -= 1.5/2.75;   return 7.5625*t*t + 0.75; }
        else if (t < 2.5/2.75){ t -= 2.25/2.75; return 7.5625*t*t + 0.9375; }
        else                { t -= 2.625/2.75;  return 7.5625*t*t + 0.984375; }
    }

    /** Lista de todos los easings para mostrar en el editor */
    public static final ALL_EASES:Array<ModEase> = [
        LINEAR, QUAD_IN, QUAD_OUT, QUAD_IN_OUT,
        CUBE_IN, CUBE_OUT, CUBE_IN_OUT,
        SINE_IN, SINE_OUT, SINE_IN_OUT,
        ELASTIC_IN, ELASTIC_OUT,
        BOUNCE_OUT, BACK_IN, BACK_OUT, INSTANT
    ];

    /** Lista de todos los tipos de evento */
    public static final ALL_TYPES:Array<ModEventType> = [
        MOVE_X, MOVE_Y, ANGLE, ALPHA, SCALE, SCALE_X, SCALE_Y,
        SPIN, RESET, SET_ABS_X, SET_ABS_Y, VISIBLE
    ];

    /** Convierte beats a steps */
    public static function beatsToSteps(beats:Float, stepsPerBeat:Int = 4):Float
        return beats * stepsPerBeat;

    /** Convierte steps a beats */
    public static function stepsToBeat(steps:Float, stepsPerBeat:Int = 4):Float
        return steps / stepsPerBeat;

    /** Descripción legible de un tipo de evento */
    public static function typeLabel(type:ModEventType):String
    {
        return switch (type)
        {
            case MOVE_X    : "Move X (offset)";
            case MOVE_Y    : "Move Y (offset)";
            case SET_ABS_X : "Set X (absolute)";
            case SET_ABS_Y : "Set Y (absolute)";
            case ANGLE     : "Angle";
            case ALPHA     : "Alpha (0-1)";
            case SCALE     : "Scale";
            case SCALE_X   : "Scale X";
            case SCALE_Y   : "Scale Y";
            case SPIN      : "Spin (deg/beat)";
            case RESET     : "Reset All";
            case VISIBLE   : "Visible (0/1)";
            default        : type;
        };
    }
}
