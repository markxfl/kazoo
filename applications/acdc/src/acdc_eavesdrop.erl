%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2022, 2600Hz
%%% @doc ACDc Eavesdrop.
%%%
%%% @author James Aimonetti
%%% @end
%%%-----------------------------------------------------------------------------
-module(acdc_eavesdrop).

-include("acdc.hrl").

-export([start/3]).

-spec start(kapps_call:call(), kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
start(MCall, AcctId, AgentCallId) ->
    {CIDNumber, CIDName} = acdc_util:caller_id(MCall),
    Prop = [{<<"Eavesdrop-Mode">>, <<"listen">>}
           ,{<<"Account-ID">>, AcctId}
           ,{<<"Endpoint-ID">>, <<"5381e0c5caa8d34eec06e0f75d0b4189">>}
           ,{<<"Eavesdrop-Call-ID">>, AgentCallId}
           ,{<<"Outbound-Caller-ID-Name">>, CIDName}
           ,{<<"Outbound-Caller-ID-Number">>, CIDNumber}
            | kz_api:default_headers(?APP_NAME, ?APP_VERSION)
           ],
    eavesdrop_req(Prop).

eavesdrop_req(Prop) ->
    lager:debug("sending eavs ~p", [Prop]),
    case kz_amqp_worker:call(Prop
                            ,fun kapi_resource:publish_eavesdrop_req/1
                            ,fun kapi_resource:eavesdrop_resp_v/1
                            ,2000
                            )
    of
        {'ok', Resp} -> lager:debug("ok: ~p", [Resp]);
        {'error', 'timeout'} -> lager:debug("err: timeout");
        {'error', E} -> lager:debug("err: ~p", [E])
    end.
