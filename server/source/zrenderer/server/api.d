module zrenderer.server.api;

import config;
import vibe.data.json;
import vibe.data.serialization;
import vibe.web.rest;
import vibe.http.status;
import vibe.http.common : HTTPStatusException;

import zrenderer.server.requestdata : RenderRequestData;
import zrenderer.server.responsedata : RenderResponseData;

@path("/")
interface ApiV1
{
    Json postRender(@viaBody() RenderRequestData data) @trusted;
}

class ApiImpl : ApiV1
{
    private Config defaultConfig;

    this(Config defaultConfig)
    {
        this.defaultConfig = defaultConfig;
    }

    Json postRender(@viaBody() RenderRequestData data) @trusted
    {
        import vibe.core.core : runWorkerTaskH;
        import zrenderer.server.worker : renderWorker;
        import std.typecons : Nullable;

        const(Config) mergedConfig = mergeConfig(defaultConfig, data);

        import validation : isJobArgValid, isCanvasArgValid;

        if (!isJobArgValid(mergedConfig.job))
        {
            throw new HTTPStatusException(HTTPStatus.badRequest, "Invalid job argument");
        }

        if (!isCanvasArgValid(mergedConfig.canvas))
        {
            throw new HTTPStatusException(HTTPStatus.badRequest, "Invalid canvas argument");
        }

        import vibe.core.task : Task;

        auto worker = runWorkerTaskH(&renderWorker, Task.getThis);

        import vibe.core.concurrency : send, receiveTimeout, OwnerTerminated;
        import std.datetime : seconds;

        send(worker, cast(immutable Config) mergedConfig);

        RenderResponseData response;
        bool renderingSucceeded = false;

        try
        {
            receiveTimeout(5.seconds,
                    (immutable(string)[] filenames) {
                        response.output = filenames;
                        renderingSucceeded = true;
                    },
                    (bool failed) {
                        renderingSucceeded = !failed;
                    }
            );
        }
        catch (OwnerTerminated e)
        {
            throw new HTTPStatusException(HTTPStatus.internalServerError, "Error during rendering process");
        }

        if (!renderingSucceeded)
        {
            throw new HTTPStatusException(HTTPStatus.internalServerError, "Error during rendering process");
        }

        return serializeToJson(response);
    }
}

const(Config) mergeConfig(Config defaultConfig, RenderRequestData data) pure nothrow @safe
{
    Config mergedConfig = defaultConfig;

    static foreach (memberName; __traits(allMembers, RenderRequestData))
    {
        static if (__traits(hasMember, mergedConfig, memberName))
        {
            static if (__traits(compiles, (__traits(getMember, data, memberName)).isNull))
            {
                if (!(__traits(getMember, data, memberName)).isNull)
                {
                    __traits(getMember, mergedConfig, memberName) = __traits(getMember, data, memberName).get();
                }
            }
            else
            {
                __traits(getMember, mergedConfig, memberName) = __traits(getMember, data, memberName);
            }
        }
    }

    return mergedConfig;
}
