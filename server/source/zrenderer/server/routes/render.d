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
import zrenderer.server.dto : RenderRequestData, RenderResponseData, toString;
import zrenderer.server.globals : defaultConfig, accessTokens;
import zrenderer.server.routes : setErrorResponse, mergeStruct, unauthorized;
import zrenderer.server.worker : renderWorker;

void handleRenderRequest(HTTPServerRequest req, HTTPServerResponse res) @trusted
{
    immutable accessToken = checkAuth(req, accessTokens);

    if (accessToken.isNull() || !accessToken.get.isValid)
    {
        unauthorized(res);
        return;
    }

    if (req.json == Json.undefined)
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Expected json input");
        return;
    }

    RenderRequestData requestData;

    try
    {
        requestData = deserializeJson!RenderRequestData(req.json);
    }
    catch (Exception err)
    {
        setErrorResponse(res, HTTPStatus.badRequest, err.msg);
        return;
    }

    logInfo(requestData.toString ~ " -- " ~ "Token: " ~ accessToken.get.description);

    const(Config) mergedConfig = mergeStruct(defaultConfig, requestData);

    if (!isJobArgValid(mergedConfig.job, accessToken.get.properties.maxJobIdsPerRequest))
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

