module resource.spr;

import resource.base;
import resource.palette : Palette;
import draw : Color, RawImage;

private enum MinSprSize = 2 + 6 + 1024;

class SprResource : BaseResource
{
    private ubyte[] _buffer;
    private Palette _palette;
    private RawImage[][2] _images;
    private ulong[][2] _imageDataOffsets;
    private ushort _ver;

    static immutable(string[]) fileExtensions = ["spr"];
    static immutable(string) filePath = "sprite";

    this(string filename, string resourcePath)
    {
        super(filename, resourcePath, filePath, fileExtensions);
    }

    /**
      Loads the file specified by filename. If the file does not exist
      an ResourceException is thrown. If there is an error during the file parsing
      a ResourceException is thrown.
      Throws: ResourceException
     */
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

        this._buffer = fileHandle.rawRead(new ubyte[fileHandle.size()]);

        this.readData(this._buffer);
        this._usable = true;
    }

    override void load(const(ubyte)[] buffer)
    {
        this._buffer = buffer.dup;
        this.readData(this._buffer);
        this._usable = true;
    }

    /**
      Returns the image corresponding to the given sprite type and index.
      If the type or index are out of bounds an empty image is instead returned.
      Returns: const(RawImage) or const(RawImage.init)
     */
    const(RawImage) image(uint index, uint sprtype) const pure nothrow @safe @nogc
    in (sprtype < 2, "Spr type can only be 0 or 1")
    {
        if (sprtype > 1 || index >= this._images[sprtype].length)
        {
            return RawImage.init;
        }

        const img = this._images[sprtype][index];
        if (img.pixels == img.pixels.init)
        {
            return RawImage.init;
        }
        return this._images[sprtype][index];
    }

    ulong numberOfImages() const pure nothrow @safe @nogc
    {
        return this._images[0].length + this._images[1].length;
    }

    ulong numberOfPalImages() const pure nothrow @safe @nogc
    {
        return this._images[0].length;
    }

    ulong numberOfRgbaImages() const pure nothrow @safe @nogc
    {
        return this._images[1].length;
    }

    ushort ver() const pure nothrow @safe @nogc
    {
        return this._ver;
    }

    const(Palette) palette() const pure nothrow @safe @nogc
    {
        return this._palette;
    }

    int opApply(scope int delegate(const(RawImage)) dg) const
    {
        int result = 0;
        foreach (const img; this._images[0])
        {
            result = dg(img);
            if (result)
            {
                break;
            }
        }
        foreach (const img; this._images[1])
        {
            result = dg(img);
            if (result)
            {
                break;
            }
        }
        return result;
    }

    int opApply(scope int delegate(ulong, const(RawImage)) dg) const
    {
        int result = 0;
        foreach (i, const img; this._images[0])
        {
            result = dg(i, img);
            if (result)
            {
                break;
            }
        }
        foreach (i, const img; this._images[1])
        {
            result = dg(i, img);
            if (result)
            {
                break;
            }
        }
        return result;
    }

    /**
       Extracts spr data from the previously loaded buffer
       If the buffer does not contain a valid spr file. A ResourceException
       is thrown.
       Throws: ResourceException
     */
    private void readData(const(ubyte)[] buffer)
    {
        import std.conv : to;
        import std.exception : enforce;

        enforce!ResourceException(buffer.length >= MinSprSize,
                "Spr file: '" ~ this.filename ~ "' does not have enough bytes to be " ~
                "valid. Has: " ~ buffer.length.to!string ~ " bytes. " ~
                "Should have: " ~ MinSprSize.to!string ~ " bytes.");

        enforce!ResourceException(buffer[0 .. 2] == ['S', 'P'],
                "Spr file: '" ~ this.filename ~ "' does not have a valid signature.");

        import std.bitmanip : littleEndianToNative, peek;
        import std.system : Endian;

        this._palette = cast(Color[]) buffer[$ - 1024 .. $];

        ulong offset = 2;

        this._ver = buffer.peekLE!ushort(&offset);
        const palImages = buffer.peekLE!ushort(&offset);
        auto rgbaImages = 0;
        if (this._ver >= 0x200)
        {
            rgbaImages = buffer.peekLE!ushort(&offset);
        }

        this._images[0] = new RawImage[palImages];
        this._images[1] = new RawImage[rgbaImages];
        this._imageDataOffsets[0] = new ulong[palImages];
        this._imageDataOffsets[1] = new ulong[rgbaImages];

        for (auto i = 0; i < palImages; ++i)
        {
            RawImage img;
            img.width = buffer.peekLE!ushort(&offset);
            img.height = buffer.peekLE!ushort(&offset);

            ulong size = img.width * img.height;

            this._imageDataOffsets[0][i] = offset;

            if (this._ver >= 0x201)
            {
                size = buffer.peekLE!ushort(&offset);
            }

            this._images[0][i] = img;

            offset += size;
        }

        if (this._ver >= 0x200)
        {
            for (auto i = 0; i < rgbaImages; ++i)
            {
                RawImage img;
                img.width = buffer.peekLE!ushort(&offset);
                img.height = buffer.peekLE!ushort(&offset);

                ulong size = img.width * img.height;

                this._imageDataOffsets[1][i] = offset;

                this._images[1][i] = img;

                offset += size * 4;
            }
        }
    }

    void loadImageData(uint index, uint sprtype, const scope Palette palette = Palette.init)
    {
        if (sprtype > 1 || index >= this._images[sprtype].length)
        {
            return;
        }

        auto img = &this._images[sprtype][index];

        if (img.pixels != img.pixels.init)
        {
            return;
        }

        const Palette pal = (palette == Palette.init) ? this._palette : palette;

        auto offset = this._imageDataOffsets[sprtype][index];
        ulong size;

        img.pixels = new Color[img.width * img.height];

        if (this._ver >= 0x201 && sprtype == 0)
        {
            size = this._buffer.peekLE!ushort(&offset);
        }
        else
        {
            size = img.width * img.height;
        }

        if (sprtype == 0)
        {
            for (auto j = 0, p = 0; j < size; ++j, ++p)
            {
                const palid = this._buffer[offset + j];
                if (palid == 0 && this._ver >= 0x201)
                {
                    const len = this._buffer[offset + j + 1];
                    img.pixels[p .. p + len] = pal[palid];
                    j++;
                    p += len - 1;
                }
                else
                {
                    img.pixels[p] = pal[palid];
                    img.pixels[p].a = palid == 0 ? 0x00 : 0xFF;
                }
            }
        }
        else if (sprtype == 1)
        {
            for (auto p = 0; p < img.pixels.length; ++p)
            {
                // RGBA images are stored with a negative y-axis
                const x = p % img.width;
                const y = (p / img.width) + 1;
                const destPixel = img.pixels.length - (y * img.width) + x;

                version (BigEndian)
                {
                    img.pixels[destPixel] = cast(Color) this._buffer.peekLE!uint(&offset);
                }
                else
                {
                    import std.bitmanip : peek;

                    img.pixels[destPixel] = cast(Color) this._buffer.peek!uint(&offset);
                }
            }
        }
    }

    void loadAllImageData(const Palette palette = Palette.init)
    {
        for (auto i = 0; i < this._images[0].length; ++i)
        {
            this.loadImageData(i, 0, palette);
        }
        for (auto i = 0; i < this._images[1].length; ++i)
        {
            this.loadImageData(i, 1, palette);
        }
    }
}
