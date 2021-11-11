module zrenderer.server.dto.renderrequest;

import vibe.data.serialization : optional;
import std.typecons : Nullable;
import config : Gender, HeadDirection, OutputFormat;

struct RenderRequestData
{
    @optional Nullable!uint action;
    @optional Nullable!int frame;
    @optional Nullable!Gender gender;
    @optional Nullable!uint head;
    @optional Nullable!uint outfit;
    @optional Nullable!uint garment;
    @optional Nullable!uint weapon;
    @optional Nullable!uint shield;
    @optional Nullable!int bodyPalette;
    @optional Nullable!int headPalette;
    @optional Nullable!HeadDirection headdir;
    @optional Nullable!bool enableShadow;
    @optional Nullable!string canvas;
    @optional Nullable!OutputFormat outputFormat;
    @optional Nullable!(uint[]) headgear;
    string[] job;
}

string toString(const scope RenderRequestData data) pure @safe
{
    import std.array : appender;
    import std.range : ElementType;
    import std.traits : isArray, isSomeString;
    import std.algorithm.iteration : joiner, map;
    import std.conv : to, ConvException;

    auto app = appender!string;

    void putArray(T)(T member, const scope string name)
    {
        app.put(name);
        app.put("=");
        static if (isSomeString!(T))
        {
            app.put("[");
            app.put(member.joiner(","));
            app.put("]");
        }
        else
        {
            app.put("[");
            try
            {
                app.put(member.map!(a => a.to!string).joiner(","));
            }
            catch (ConvException err)
            {
                app.put("?");
            }
            app.put("]");
        }
        app.put(", ");
    }

    void putSingle(T)(T member, const scope string name)
    {
        app.put(name);
        app.put("=");
        static if (isSomeString!(T))
        {
            app.put(member);
        }
        else
        {
            try
            {
                app.put(member.to!string);
            }
            catch (ConvException err)
            {
                app.put("?");
            }
        }
        app.put(", ");
    }

    app.put("RenderRequestData { ");

    putArray(data.job, "job");
    if (!data.action.isNull) putSingle(data.action.get, "action");
    if (!data.frame.isNull) putSingle(data.frame.get, "frame");
    if (!data.gender.isNull) putSingle(data.gender.get, "gender");
    if (!data.head.isNull) putSingle(data.head.get, "head");
    if (!data.outfit.isNull) putSingle(data.outfit.get, "outfit");
    if (!data.garment.isNull) putSingle(data.garment.get, "garment");
    if (!data.weapon.isNull) putSingle(data.weapon.get, "weapon");
    if (!data.shield.isNull) putSingle(data.shield.get, "shield");
    if (!data.bodyPalette.isNull) putSingle(data.bodyPalette.get, "bodyPalette");
    if (!data.headPalette.isNull) putSingle(data.headPalette.get, "headPalette");
    if (!data.headdir.isNull) putSingle(data.headdir.get, "headdir");
    if (!data.enableShadow.isNull) putSingle(data.enableShadow.get, "enableShadow");
    if (!data.canvas.isNull) putSingle(data.canvas.get, "canvas");
    if (!data.outputFormat.isNull) putSingle(data.outputFormat.get, "outputFormat");
    if (!data.headgear.isNull) putArray(data.headgear.get, "headgear");

    return app.data[0 .. $ - 2] ~ " }";
}

