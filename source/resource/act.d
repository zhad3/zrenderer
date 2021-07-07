module resource.act;

import resource.base;
import draw : Color;

struct ActAction
{
    float interval = 4;
    ActFrame[] frames;
}

struct ActFrame
{
    int eventId;
    ActSprite[] sprites;
    ActAttachPoint[] attachPoints;
}

struct ActSprite
{
    int x;
    int y;
    int sprId;
    uint flags;
    Color tint;
    float xScale;
    float yScale;
    int rotation;
    int sprType;
    int width;
    int height;
}

struct ActAttachPoint
{
    int x;
    int y;
    int attr;
}

private enum MinActSize = 18 + 2 + 10;

class ActResource : BaseResource
{
    private ubyte[] _buffer;
    private ActAction[] _actions;
    private string[] _events;
    private ushort _ver;

    static immutable(string[]) fileExtensions = ["act"];
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

        this.readData();
        this._usable = true;
    }

    ushort ver() const pure nothrow @safe @nogc
    {
        return this._ver;
    }

    ulong numberOfActions() const pure nothrow @safe @nogc
    {
        return this._actions.length;
    }

    ulong numberOfEvents() const pure nothrow @safe @nogc
    {
        return this._events.length;
    }

    ulong numberOfFrames(uint action) const pure nothrow @safe @nogc
    {
        if (action >= this.numberOfActions)
        {
            return 0;
        }

        return this._actions[action].frames.length;
    }

    ulong numberOfSprites(uint action, uint frame) const pure nothrow @safe @nogc
    {
        if (frame >= this.numberOfFrames(action))
        {
            return 0;
        }

        return this._actions[action].frames[frame].sprites.length;
    }

    ulong numberOfAttachpoints(uint action, uint frame) const pure nothrow @safe @nogc
    {
        if (frame >= this.numberOfFrames(action))
        {
            return 0;
        }

        return this._actions[action].frames[frame].attachPoints.length;
    }

    const(ActAction) action(uint action) const pure nothrow @safe @nogc
    {
        if (action >= this.numberOfActions)
        {
            return ActAction.init;
        }

        return this._actions[action];
    }

    const(ActAction)[] actions() const pure nothrow @safe @nogc
    {
        return this._actions;
    }

    const(ActFrame) frame(uint action, uint frame) const pure nothrow @safe @nogc
    {
        if (frame >= this.numberOfFrames(action))
        {
            return ActFrame.init;
        }

        return this._actions[action].frames[frame];
    }

    const(ActFrame)[] frames(uint action) const pure nothrow @safe @nogc
    {
        if (action >= this.numberOfActions)
        {
            return ActFrame[].init;
        }

        return this._actions[action].frames;
    }

    const(ActSprite) sprite(uint action, uint frame, uint sprite) const pure nothrow @safe @nogc
    {
        if (sprite >= this.numberOfSprites(action, frame))
        {
            return ActSprite.init;
        }

        return this._actions[action].frames[frame].sprites[sprite];
    }

    const(ActSprite)[] sprites(uint action, uint frame) const pure nothrow @safe @nogc
    {
        if (frame >= this.numberOfFrames(action))
        {
            return ActSprite[].init;
        }

        return this._actions[action].frames[frame].sprites;
    }

    const(ActAttachPoint) attachpoint(uint action, uint frame, uint attachpoint) const pure nothrow @safe @nogc
    {
        if (attachpoint >= this.numberOfAttachpoints(action, frame))
        {
            return ActAttachPoint.init;
        }

        return this._actions[action].frames[frame].attachPoints[attachpoint];
    }

    const(ActAttachPoint)[] attachpoints(uint action, uint frame) const pure nothrow @safe @nogc
    {
        if (frame >= this.numberOfFrames(action))
        {
            return ActAttachPoint[].init;
        }

        return this._actions[action].frames[frame].attachPoints;
    }

    void modifySprite(string prop, ValueType)(uint action, uint frame, uint sprite,
            ValueType value) pure nothrow @safe @nogc
            if (canSetProp!(prop, ActSprite, ValueType))
    {
        __traits(getMember, this._actions[action].frames[frame].sprites[sprite], prop) = value;
    }

    void modifyAttachpoint(string prop, ValueType)(uint action, uint frame, uint attachpoint,
            ValueType value) pure nothrow @safe @nogc
            if (canSetProp!(prop, ActAttachPoint, ValueType))
    {
        __traits(getMember, this._actions[action].frames[frame].attachPoints[attachpoint], prop) = value;
    }

    int opApply(scope int delegate(const(ActAction)) dg) const
    {
        int result = 0;
        foreach (const action; this._actions)
        {
            result = dg(action);
            if (result)
            {
                break;
            }
        }
        return result;
    }

    int opApply(scope int delegate(ulong, const(ActAction)) dg) const
    {
        int result = 0;
        foreach (i, const action; this._actions)
        {
            result = dg(i, action);
            if (result)
            {
                break;
            }
        }
        return result;
    }

    /**
      Extracts act data from the previously loaded buffer
      If the buffer does not contain a valid act file. A ResourceException
      is thrown.
      Throws: ResourceException
     */
    private void readData()
    {
        import std.conv : to;
        import std.exception : enforce;

        enforce!ResourceException(this._buffer.length >= MinActSize,
                "Act file: '" ~ this.filename ~ "' does not have enough bytes to be " ~
                "valid. Has: " ~ this._buffer.length.to!string ~ " bytes. " ~
                "Should have: " ~ MinActSize.to!string ~ " bytes.");

        enforce!ResourceException(this._buffer[0 .. 2] == ['A', 'C'],
                "Act file: '" ~ this.filename ~ "' does not have a valid signature.");

        ulong offset = 2;
        this._ver = this._buffer.peekLE!ushort(&offset);
        const numberOfActions = this._buffer.peekLE!ushort(&offset);
        offset += 10; // skip reserved bytes

        this._actions = new ActAction[numberOfActions];

        foreach (ref action; this._actions)
        {
            const numberOfFrames = this._buffer.peekLE!uint(&offset);
            if (numberOfFrames > 0)
            {
                action.frames = new ActFrame[numberOfFrames];

                foreach (ref frame; action.frames)
                {
                    this.readFrame(frame, offset);
                }
            }
        }

        if (this._ver >= 0x201)
        {
            const numberOfEvents = this._buffer.peekLE!uint(&offset);
            if (numberOfEvents > 0)
            {
                this._events = new string[numberOfEvents];

                foreach (ref event; this._events)
                {
                    import std.string : fromStringz;

                    event = fromStringz(cast(char*)&this._buffer[offset]).dup;
                    offset += 40;
                }
            }

            if (this._ver >= 0x202)
            {
                foreach (ref action; this._actions)
                {
                    action.interval = this._buffer.peekLE!float(&offset);
                }
            }
        }

        assert(offset == this._buffer.length, "Offset of act file is not EOF");
    }

    private void readFrame(ref ActFrame frame, ref ulong offset) pure nothrow
    {
        // Skip attackRange and fitRange
        offset += uint.sizeof * 8;
        const numberOfSprites = this._buffer.peekLE!uint(&offset);
        if (numberOfSprites > 0)
        {
            frame.sprites = new ActSprite[numberOfSprites];

            foreach (ref sprite; frame.sprites)
            {
                this.readSprite(sprite, offset);
            }
        }

        if (this._ver >= 0x200)
        {
            frame.eventId = this._buffer.peekLE!int(&offset);

            if (this._ver >= 0x203)
            {
                const numberOfAttachPoints = this._buffer.peekLE!uint(&offset);
                if (numberOfAttachPoints > 0)
                {
                    frame.attachPoints = new ActAttachPoint[numberOfAttachPoints];

                    foreach (ref attachpoint; frame.attachPoints)
                    {
                        this.readAttachPoint(attachpoint, offset);
                    }
                }
            }
        }
    }

    private void readSprite(ref ActSprite sprite, ref ulong offset) pure nothrow @nogc
    {
        sprite.x = this._buffer.peekLE!int(&offset);
        sprite.y = this._buffer.peekLE!int(&offset);
        sprite.sprId = this._buffer.peekLE!int(&offset);
        sprite.flags = this._buffer.peekLE!uint(&offset);
        sprite.tint = this._buffer.peekLE!uint(&offset);
        sprite.xScale = this._buffer.peekLE!float(&offset);
        if (this._ver >= 0x204)
        {
            sprite.yScale = this._buffer.peekLE!float(&offset);
        }
        else
        {
            sprite.yScale = sprite.xScale;
        }
        sprite.rotation = this._buffer.peekLE!int(&offset);
        sprite.sprType = this._buffer.peekLE!int(&offset);
        if (this._ver >= 0x205)
        {
            sprite.width = this._buffer.peekLE!int(&offset);
            sprite.height = this._buffer.peekLE!int(&offset);
        }
    }

    private void readAttachPoint(ref ActAttachPoint attachpoint, ref ulong offset) pure nothrow @nogc
    {
        offset += ubyte.sizeof * 4;
        attachpoint.x = this._buffer.peekLE!int(&offset);
        attachpoint.y = this._buffer.peekLE!int(&offset);
        attachpoint.attr = this._buffer.peekLE!int(&offset);
    }
}
