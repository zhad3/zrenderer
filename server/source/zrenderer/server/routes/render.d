module zrenderer.server.routes.render;

import config;
import std.datetime : seconds;
import std.typecons : Nullable;
import std.zip : ArchiveMember, ZipArchive;
import validation : isJobArgValid, isCanvasArgValid;
import vibe.core.concurrency : send, receiveTimeout, OwnerTerminated;
import vibe.core.core : runWorkerTaskH;
import vibe.core.log : logInfo, logError;
import vibe.core.task : Task;
import vibe.data.json;
import vibe.data.serialization;
import vibe.http.common : HTTPStatusException;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import vibe.http.status;
import zrenderer.server.auth : AccessToken, checkAuth;
import zrenderer.server.globals : defaultConfig, accessTokens;
import zrenderer.server.requestdata : RenderRequestData, toString;
import zrenderer.server.responsedata : RenderResponseData;
import zrenderer.server.routes : setErrorResponse;
import zrenderer.server.worker : renderWorker;

void handleRenderRequest(HTTPServerRequest req, HTTPServerResponse res) @trusted
{
    immutable accessToken = checkAuth(req, accessTokens);

    if (!accessToken.isValid)
    {
        setErrorResponse(res, HTTPStatus.unauthorized, "Missing or invalid access token");
        return;
    }

    if (req.json == Json.undefined)
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Expected json input");
        return;
    }

    RenderRequestData requestData = deserializeJson!RenderRequestData(req.json);

    logInfo(requestData.toString ~ " -- " ~ "Token: " ~ accessToken.description);

    const(Config) mergedConfig = mergeConfig(defaultConfig, requestData);

    if (!isJobArgValid(mergedConfig.job))
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Invalid job element");
        return;
    }

    if (!isCanvasArgValid(mergedConfig.canvas))
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Invalid canvas element");
        return;
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
        setErrorResponse(res, HTTPStatus.internalServerError, "Rendering timed out / was aborted");
        return;
    }

    if (!renderingSucceeded)
    {
        setErrorResponse(res, HTTPStatus.internalServerError, "Error during rendering process");
        return;
    }

    import std.file : read, FileException;

    if (mergedConfig.outputFormat == OutputFormat.zip)
    {

        if (response.output.length == 0)
        {
            setErrorResponse(res, HTTPStatus.noContent, "Nothing rendered");
            return;
        }

        res.contentType("application/zip");
        try
        {
            res.writeBody(cast(ubyte[]) read(response.output[$-1]));
        }
        catch (FileException err)
        {
            logError(err.message);
            setErrorResponse(res, HTTPStatus.internalServerError, "Error when writing response");
            return;
        }
    }
    else
    {
        import std.exception : ifThrown;

        bool downloadImage = (req.query["downloadimage"].length >= 0).ifThrown(false);

        if (downloadImage)
        {
            if (response.output.length == 0)
            {
                setErrorResponse(res, HTTPStatus.noContent, "Nothing rendered");
                return;
            }

            res.contentType("image/png");
            try
            {
                res.writeBody(cast(ubyte[]) read(response.output[0]));
            }
            catch (FileException err)
            {
                logError(err.message);
                setErrorResponse(res, HTTPStatus.internalServerError, "Error when writing response");
                return;
            }
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

