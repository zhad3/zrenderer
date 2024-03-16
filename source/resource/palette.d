module resource.palette;

import resource.base;
import draw : Color;

alias Palette = Color[];

class PaletteResource : BaseResource
{
    private Palette _palette;

    static immutable(string[]) fileExtensions = ["pal"];
    static immutable(string) filePath = "palette";

    this(string filename, string resourcePath)
    {
        super(filename, resourcePath, filePath, fileExtensions);
    }

    override void load()
    {
        if (this.filename.length == 0)
        {
            return;
        }

        import std.stdio : File;
        import std.exception : collectException, ErrnoException, enforce;

        File fileHandle;
        auto err = collectException!ErrnoException(
                File(this.filename, "rb"),
                fileHandle);

        enforce!ResourceException(!err, err.msg); // Re-throw ErrnoException as ResourceException

        this._palette = fileHandle.rawRead(new Color[256]);

        this._usable = true;
    }

    override void load(const(ubyte)[] buffer)
    {
        if (buffer.length < 256)
        {
            return;
        }

        this._palette = cast(Color[]) buffer[0 .. 256].dup;
        this._usable = true;
    }

    const(Palette) palette() const pure nothrow @safe @nogc
    {
        return this._palette;
    }

    int opApply(scope int delegate(const(Color)) dg)
    {
        int result = 0;
        foreach (const color; this._palette)
        {
            result = dg(color);
            if (result)
            {
                break;
            }
        }
        return result;
    }

    int opApply(scope int delegate(ulong, const(Color)) dg)
    {
        int result = 0;
        foreach (i, const color; this._palette)
        {
            result = dg(i, color);
            if (result)
            {
                break;
            }
        }
        return result;
    }
}
