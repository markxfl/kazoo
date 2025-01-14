%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2021, 2600Hz
%%% @doc
%%% @author Pierre Fenoll
%%% @end
%%%-----------------------------------------------------------------------------
-module(knm_converters_tests).

-define(MODULE_TESTED, knm_converters).

-ifdef(PROPER).
-include_lib("proper/include/proper.hrl").
-endif.
-include_lib("eunit/include/eunit.hrl").

-include_lib("kazoo_number_manager/include/knm_phone_number.hrl").

%% PROPER TESTING
-ifdef(PROPER).
%%
%%% 1000000000
%% (AAABBBCCCC, 1AAABBBCCCC) -> AAABBBCCCCCC.
prop_to_npan() ->
    ?FORALL(Number
           ,range(2002000000,19999999999)
           ,begin
                BinNum = kz_term:to_binary(Number),
                NPAN = ?MODULE_TESTED:to_npan(BinNum),
                case byte_size(BinNum) of
                    11 -> BinNum =:= <<"1", NPAN/binary>>;
                    _ -> NPAN =:= BinNum
                end
            end
           ).

%% (AAABBBCCCC, 1AAABBBCCCC) -> 1AAABBBCCCCCC.
prop_to_1npan() ->
    ?FORALL(Number
           ,range(2002000000,19999999999)
           ,begin
                BinNum = kz_term:to_binary(Number),
                OneNPAN = ?MODULE_TESTED:to_1npan(BinNum),
                case byte_size(BinNum) of
                    11 -> OneNPAN =:= BinNum;
                    _ -> OneNPAN =:= <<"1", BinNum/binary>>
                end
            end
           ).

%% (AAABBBCCCC, 1AAABBBCCCC) -> +1AAABBBCCCCCC.
prop_normalize() ->
    ?FORALL(Number
           ,range(2002000000,19999999999)
           ,begin
                BinNum = kz_term:to_binary(Number),
                E164 = ?MODULE_TESTED:normalize(BinNum),
                case byte_size(BinNum) of
                    11 -> E164 =:= <<$+, BinNum/binary>>;
                    10 -> E164 =:= <<$+, $1, BinNum/binary>>;
                    _ -> E164 =:= BinNum
                end
            end
           ).

proper_test_() ->
    {"Runs the module's PropEr tests during eunit testing",
     {'timeout', 15000,
      [
       ?_assertEqual([], proper:module(?MODULE, [{'max_shrinks', 0}]))
      ]}}.

-endif.

%% EUNIT TESTING
%%

normalize_test_() ->
    [?_assertEqual(<<"+12234567890">>, ?MODULE_TESTED:normalize(N))
     || N <- [<<"+12234567890">>, <<"12234567890">>, <<"2234567890">>]
    ].

to_npan_test_() ->
    [?_assertEqual(<<"2234567890">>, ?MODULE_TESTED:to_npan(N))
     || N <- [<<"+12234567890">>, <<"12234567890">>, <<"2234567890">>]
    ].

to_1npan_test_() ->
    [?_assertEqual(<<"12234567890">>, ?MODULE_TESTED:to_1npan(N))
     || N <- [<<"+12234567890">>, <<"12234567890">>, <<"2234567890">>]
    ].

converters_fields_in_order_test_() ->
    Props = kz_json:to_proplist(knm_converter_regex:get_e164_converters()),
    [?_assertEqual(lists:nth(3, Props)
                  ,{<<"^[2-9]\\d{7,}$">>, kz_json:from_list([{<<"prefix">>, <<"+">>}])}
                  )
    ,?_assertEqual(lists:nth(2, Props)
                  ,{<<"^011(\\d{5,})$|^00(\\d{5,})$">>, kz_json:from_list([{<<"prefix">>, <<"+">>}])}
                  )
    ,?_assertEqual(lists:nth(1, Props)
                  ,{<<"^(\\+?1)?([2-9][0-9]{2}[2-9][0-9]{6})$">>, kz_json:from_list([{<<"prefix">>, <<"+1">>}])}
                  )
    ].

to_db_test_() ->
    Ns = [{<<"+14158867900">>, <<?KNM_DB_PREFIX_ENCODED, "%2B1415">>}
         ,{<<"14158867900">>, <<?KNM_DB_PREFIX_ENCODED, "14158">>}
         ,{<<"1234">>, 'undefined'}
         ],
    [?_assertEqual(Db, knm_converters:to_db(N)) || {N, Db} <- Ns].

%% HELP-15556: classifiers missing 'friendly_name' would be
%% "corrected" into the accumulator object instead of the classifier
%% settings
available_classifiers_test_() ->
    NoNameClassifier = {<<"noname">>, kz_json:from_list([{<<"regex">>, kz_binary:rand_hex(4)}])},

    NameClassifier = {<<"name">>
                     ,kz_json:from_list([{<<"friendly_name">>, kz_binary:rand_hex(4)}
                                        ,{<<"regex">>, kz_binary:rand_hex(4)}
                                        ])
                     },
    Tests = [NoNameClassifier
            ,NameClassifier
            ],

    Corrected = knm_converters:available_classifiers(kz_json:from_list(Tests)),

    [correct_correction(Test, Corrected) || Test <- Tests].

correct_correction({ClassifierName, ClassifierSettings}
                  ,CorrectedClassifiers
                  ) ->

    [?_assertEqual(kz_json:get_value(<<"friendly_name">>, ClassifierSettings, ClassifierName)
                  ,kz_json:get_value([ClassifierName, <<"friendly_name">>], CorrectedClassifiers)
                  )
    ,?_assertEqual(kz_json:get_value(<<"regex">>, ClassifierSettings)
                  ,kz_json:get_value([ClassifierName, <<"regex">>], CorrectedClassifiers)
                  )
    ].
