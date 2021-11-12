module zrenderer.server.dto.accesstoken;

import std.typecons : Nullable;
import vibe.data.serialization : optional;
import zrenderer.server.auth : Capabilities, Properties;

struct AccessTokenData
{
    @optional Nullable!uint id;
    @optional Nullable!string description;
    @optional Nullable!bool isAdmin;
    @optional Nullable!CapabilitiesData capabilities;
    @optional Nullable!PropertiesData properties;
}

struct CapabilitiesData
{
    mixin(optionalStructOf!Capabilities);
}

struct PropertiesData
{
    mixin(optionalStructOf!Properties);
}

template optionalStructOf(T)
{
    string optionalStructOf()
    {
        import std.meta : AliasSeq;
        import std.traits : Fields, FieldNameTuple;

        string output;
        alias Types = Fields!T;
        alias Names = FieldNameTuple!T;
        static foreach (i, name; Names)
        {
            output ~= "@optional Nullable!" ~ Types[i].stringof ~ " " ~ name ~ ";";
        }

        return output;
    }
}

