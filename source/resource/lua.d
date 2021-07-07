module resource.lua;

import resource.base;

class LuaResource : BaseResource
{
    private ubyte[] _buffer;

    static immutable(string[]) fileExtensions = ["lub", "lua"];
    static immutable(string) filePath = "luafiles514/lua files";

    this(string filename, string resourcePath)
    {
        super(filename, resourcePath, filePath, fileExtensions);
    }

    override void load()
    {
        if (this._filename.length == 0)
        {
            return;
        }

        bool fileFound = false;

        foreach (extension; this.fileExtensions)
        {
            import std.path : setExtension;

            this._filename = setExtension(this._filename, extension);

            import std.file : exists;

            fileFound = this.filename.exists;
            if (fileFound)
            {
                break;
            }
        }

        import std.exception : enforce;
        import std.format : format;

        enforce!ResourceException(fileFound, format("LuaResource (%s) does not exist.", this.name));

        import std.stdio : File;
        import std.exception : collectException, ErrnoException;

        File fileHandle;
        auto err = collectException!ErrnoException(
                File(this.filename, "rb"),
                fileHandle);

        enforce!ResourceException(!err, err.msg); // Re-throw ErrnoException as ResourceException

        this._buffer = fileHandle.rawRead(new ubyte[fileHandle.size()]);

        this._usable = true;
    }

    import luad.state : LuaState;

    void loadIntoLuaState(ref LuaState L)
    {
        if (this._buffer.length == 0)
        {
            return;
        }

        import luad.error : LuaErrorException;

        try
        {
            import luad.c.lua : lua_gettop, lua_pop, lua_pcall, lua_error, LUA_MULTRET;
            import luad.c.lauxlib : luaL_loadbuffer;
            import std.exception : enforce;

            const top = lua_gettop(L.state);

            auto ret = luaL_loadbuffer(L.state, cast(char*) this._buffer.ptr, this._buffer.length,
                    this._filename.ptr);

            if (ret > 0)
            {
                lua_error(L.state);
            }

            //enforce!ResourceException(lua_pcall(L.state, 0, LUA_MULTRET, 0) == 0, "Error loading lua resource.");
            ret = lua_pcall(L.state, 0, LUA_MULTRET, 0);
            if (ret > 0)
            {
                lua_error(L.state);
            }

            const ntop = lua_gettop(L.state);
            lua_pop(L.state, ntop - top);
        }
        catch (LuaErrorException err)
        {
            throw new ResourceException(err.msg);
        }
    }
}
