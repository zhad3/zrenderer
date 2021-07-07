module resource.imf;

import resource.base;

struct ImfFrame
{
    int priority;
    // We don't use these
    //int cx;
    //int cy;
}

class ImfResource : BaseResource
{
    private
    {
        ubyte[] _buffer;
        float _ver;
        enum MAX_LAYER = 20;
        enum MAX_ACTION = 600;
        ImfFrame[][][] _data;
    }

    static immutable(string[]) fileExtensions = ["imf"];
    static immutable(string) filePath = "imf";

    this(string filename, string resourcePath)
    {
        super(filename, resourcePath, filePath, fileExtensions);
    }

    int layer(uint priority, uint action, uint frame) const pure nothrow @safe @nogc
    {
        if (priority >= this._data.length ||
                action >= this._data[priority].length ||
                frame >= this._data[priority][action].length)
        {
            return -1;
        }

        for (auto layer = 0; layer < this._data.length; ++layer)
        {
            if (this._data[layer][action][frame].priority == priority)
            {
                return layer;
            }
        }

        return -1;
    }

    int priority(uint layer, uint action, uint frame) const pure nothrow @safe @nogc
    {
        if (layer >= this._data.length ||
                action >= this._data[layer].length ||
                frame >= this._data[layer][action].length)
        {
            return -1;
        }

        return this._data[layer][action][frame].priority;
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

        this.readData();
        this._usable = true;
    }

    float ver() const pure nothrow @safe @nogc
    {
        return this._ver;
    }

    private void readData()
    {
        ulong offset = 0;
        this._ver = this._buffer.peekLE!float(&offset);

        // skip checksum (int) because it is unused
        offset += 4;

        uint maxLayer = this._buffer.peekLE!uint(&offset);

        this._data = new ImfFrame[][][maxLayer + 1];

        for (auto layer = 0; layer <= maxLayer; ++layer)
        {
            uint numActions = this._buffer.peekLE!uint(&offset);
            this._data[layer] = new ImfFrame[][numActions];

            for (auto action = 0; action < numActions; ++action)
            {
                uint numFrames = this._buffer.peekLE!uint(&offset);
                this._data[layer][action] = new ImfFrame[numFrames];

                for (auto frame = 0; frame < numFrames; ++frame)
                {
                    auto frameData = &this._data[layer][action][frame];
                    frameData.priority = this._buffer.peekLE!int(&offset);

                    // We skip cx and cy because we have no use for it
                    //frameData.cx = this._buffer.peekLE!int(&offset);
                    //frameData.cy = this._buffer.peekLE!int(&offset);
                    offset += 8;
                }
            }
        }
    }
}
