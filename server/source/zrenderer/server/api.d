module zrenderer.server.api;

import config;
import std.datetime : seconds;
import std.typecons : Nullable;
import std.zip : ArchiveMember, ZipArchive;
import validation : isJobArgValid, isCanvasArgValid;
import vibe.core.concurrency : send, receiveTimeout, OwnerTerminated;
import vibe.core.core : runWorkerTaskH;
import vibe.core.log : logInfo;
import vibe.core.task : Task;
import vibe.data.json;
import vibe.data.serialization;
import vibe.http.common : HTTPStatusException;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import vibe.http.status;
import vibe.web.rest;
import zrenderer.server.requestdata : RenderRequestData, toString;
import zrenderer.server.responsedata : RenderResponseData;
import zrenderer.server.worker : renderWorker;

__gshared Config defaultConfig;

void handleRenderRequest(HTTPServerRequest req, HTTPServerResponse res) @trusted
{
    if (req.json == Json.undefined)
    {
        throw new HTTPStatusException(HTTPStatus.badRequest, "Expected json input");
    }

    RenderRequestData requestData = deserializeJson!RenderRequestData(req.json);

    logInfo(requestData.toString);

    const(Config) mergedConfig = mergeConfig(defaultConfig, requestData);

    if (!isJobArgValid(mergedConfig.job))
    {
        throw new HTTPStatusException(HTTPStatus.badRequest, "Invalid job argument");
    }

    if (!isCanvasArgValid(mergedConfig.canvas))
    {
        throw new HTTPStatusException(HTTPStatus.badRequest, "Invalid canvas argument");
    }

    auto worker = runWorkerTaskH(&renderWorker, Task.getThis);
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

    import std.file : read;

    if (mergedConfig.outputFormat == OutputFormat.zip)
    {

        if (response.output.length == 0)
        {
            throw new HTTPStatusException(HTTPStatus.noContent);
        }

        res.contentType("application/zip");
        res.writeBody(cast(ubyte[]) read(response.output[$-1]));
    }
    else
    {
        import std.exception : ifThrown;

        bool downloadImage = (req.query["downloadimage"].length >= 0).ifThrown(false);

        if (downloadImage)
        {
            if (response.output.length == 0)
            {
                throw new HTTPStatusException(HTTPStatus.noContent);
            }

            res.contentType("image/png");
            res.writeBody(cast(ubyte[]) read(response.output[0]));
        }
        else
        {
            res.writeJsonBody(serializeToJson(response));
        }
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
