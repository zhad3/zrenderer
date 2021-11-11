module zrenderer.server.routes;

public import zrenderer.server.routes.admin;
public import zrenderer.server.routes.render;

import vibe.data.json;
import vibe.http.server : HTTPServerResponse;
import vibe.http.status;

void setErrorResponse(ref HTTPServerResponse res, HTTPStatus httpStatus, const scope string message = string.init)
{
    res.statusCode = httpStatus;
    auto jsonResponse = Json(["statusMessage": Json(message)]);
    res.writeJsonBody(jsonResponse);
}

T mergeStruct(T, S)(T target, S source) pure nothrow @safe
{
    T mergedStruct = target;

    static foreach (memberName; __traits(allMembers, S))
    {
        static if (__traits(hasMember, mergedStruct, memberName))
        {
            static if (__traits(compiles, (__traits(getMember, source, memberName)).isNull))
            {
                if (!(__traits(getMember, source, memberName)).isNull)
                {
                    static if (is(typeof(__traits(getMember, source, memberName).get) == struct) && is(typeof(__traits(getMember, target, memberName)) == struct))
                    {
                        __traits(getMember, mergedStruct, memberName) = mergeStruct!(typeof(__traits(getMember, target, memberName)), typeof(__traits(getMember, source, memberName).get))(__traits(getMember, target, memberName), __traits(getMember, source, memberName).get);
                    }
                    else
                    {
                        __traits(getMember, mergedStruct, memberName) = __traits(getMember, source, memberName).get();
                    }
                }
            }
            else
            {
                static if (is(typeof(__traits(getMember, source, memberName).get) == struct) && is(typeof(__traits(getMember, target, memberName)) == struct))
                {
                    __traits(getMember, mergedStruct, memberName) = mergeStruct!(typeof(__traits(getMember, target, memberName)), typeof(__traits(getMember, source, memberName)))(__traits(getMember, target, memberName), __traits(getMember, source, memberName));
                }
                else
                {
                    __traits(getMember, mergedStruct, memberName) = __traits(getMember, source, memberName);
                }
            }
        }
    }

    return mergedStruct;
}

