module zrenderer.server.responsedata;

struct RenderResponseData
{
    /// Status of 0 means OK. Anything above is an error.
    int status;
    /// Contains a message regarding the returned status. On status 0 it reads "OK", otherwise an error message.
    string message;
    /// Contains one or more paths to the rendered sprites.
    immutable(string)[] renders;
}
