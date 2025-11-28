-module(mcp_bridge_http_auth).

-behaviour(cowboy_middleware).

-export([execute/2]).

execute(Req, Env) ->
    Headers = cowboy_req:headers(Req),
    JwtToken = get_jwt_token(Headers),
    case validate_jwt(JwtToken) of
        {ok, JwtClaims} ->
            {ok, Req#{jwt_claims => JwtClaims}, Env};
        {error, invalid_token} ->
            Req2 = cowboy_req:reply(401, #{}, <<"Unauthorized">>, Req),
            {stop, Req2}
    end.

get_jwt_token(Headers) ->
    case string:split(maps:get(<<"authorization">>, Headers, <<>>), " ") of
        [<<"Bearer">>, Token] -> Token;
        _ -> undefined
    end.

validate_jwt(undefined) ->
    %% Allow requests without JWT for now
    {ok, #{}};
validate_jwt(JwtToken) ->
    #{jwt_secret := Secret} = mcp_bridge:get_config(),
    try
        {true, Payload, _} = jose_jws:verify(jose_jwk:from_oct(Secret), JwtToken),
        Claims = emqx_utils_json:decode(Payload),
        {ok, Claims}
    catch
        _:_ -> {error, invalid_token}
    end.
