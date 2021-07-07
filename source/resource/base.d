module resource.base;

class ResourceException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

private enum PathPrefix = "data";

string buildFilepath(immutable(string) resourcePath, immutable(string) filePath,
       immutable(string) filename, immutable(string) fileExtension) pure nothrow @safe
{
    import std.path : buildPath, setExtension;

    return buildPath(resourcePath, PathPrefix, filePath, filename).setExtension(fileExtension);
}

string buildFilepath(immutable(string) resourcePath, immutable(string) filePath,
        immutable(string) filename) pure nothrow @safe
{
    import std.path : buildPath, setExtension;

    return buildPath(resourcePath, PathPrefix, filePath, filename);
}

package class BaseResource
{
protected:
    string _filename;
    string _name;
    bool _usable = false;

public:
    static immutable(string[]) fileExtensions = [];
    static immutable(string) filePath = "";

    this(string filename, string resourcePath, immutable(string) filePath, immutable(string[]) fileExtensions)
    {
        import std.path : buildPath, setExtension;

        this._name = filename;

        if (fileExtensions.length == 1)
        {
            this._filename = buildFilepath(resourcePath, filePath, filename, fileExtensions[0]);
        }
        else
        {
            this._filename = buildFilepath(resourcePath, filePath, filename);
        }
    }

    abstract void load();

    bool usable() const pure nothrow @safe @nogc
    {
        return this._usable;
    }

    const(string) filename() const pure nothrow @safe @nogc
    {
        return this._filename;
    }

    const(string) name() const pure nothrow @safe @nogc
    {
        return this._name;
    }
}

import std.bitmanip : peek;
import std.system : Endian;

T peekLE(T, R)(R range)
{
    return peek!(T, Endian.littleEndian, R)(range);
}

T peekLE(T, R)(R range, size_t index)
{
    return peek!(T, Endian.littleEndian, R)(range, index);
}

T peekLE(T, R)(R range, size_t* index)
{
    return peek!(T, Endian.littleEndian, R)(range, index);
}

import std.traits : isImplicitlyConvertible;

package template canSetProp(string prop, DataStruct, ValueType)
{
    enum canSetProp = __traits(hasMember, DataStruct, prop) &&
            (is(typeof(__traits(getMember, DataStruct, prop) == ValueType)) ||
            isImplicitlyConvertible!(ValueType, typeof(__traits(getMember, DataStruct, prop))));
}

