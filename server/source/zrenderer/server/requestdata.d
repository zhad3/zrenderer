module zrenderer.server.requestdata;

import vibe.data.serialization : optional;
import std.typecons : Nullable;
import config : Gender;

struct RenderRequestData
{
    @optional Nullable!uint action;
    @optional Nullable!int frame;
    @optional Nullable!Gender gender;
    @optional Nullable!uint head;
    @optional Nullable!uint garment;
    @optional Nullable!uint weapon;
    @optional Nullable!uint shield;
    @optional Nullable!int bodyPalette;
    @optional Nullable!int headPalette;
    @optional Nullable!bool enableShadow;
    @optional Nullable!(uint[]) headgear;
    string[] job;
}
