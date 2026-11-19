/* Promela/SPIN model of the bounded account-recovery agentic system. */
/* -DMODE=0: Reference LLM composition for design-time verification. */
/* -DMODE=1: Arbitrary LLM proposals without enforcement. */
/* -DMODE=2: Arbitrary LLM proposals with reference transition enforcement. */
/* -DCHECK_TRACE: Check agent invocations using an independent protocol observer. */
/* -DCHECK_ONCE: Verify at most one executed update per session. */
/* -DCOVER_UPDATE: Refute "no update ever" to witness update reachability. */
/* -DCOVER_REJECTION: Refute "no rejection ever" to witness rejection reachability. */
/* Default (no check flag): Verify authorization and at-most-once safety. */

#ifndef MODE
#define MODE 0
#endif

mtype = { VERIFY, UPDATE, VERIFIED, FAILED, ALLOWED, REJECTED };

#define UNVERIFIED 0
#define VERIFIED_STATE 1
#define COMPLETED 2

#define ENABLED(q,a) (((a) == VERIFY && (q) != COMPLETED) || \
                      ((a) == UPDATE && (q) == VERIFIED_STATE))
#define AFTER_SUCCESSFUL_VERIFY(q) VERIFIED_STATE
#define AFTER_UPDATE(q) COMPLETED

chan proposal = [0] of { mtype, bit };
chan decision = [0] of { mtype };
chan dispatch = [0] of { mtype, bit };
chan result   = [0] of { mtype, bit, bit };

byte model_phase[2];

byte observed_phase[2];
bool trace_violation;
bool rejected;  

bool actually_verified[2];
bool updated[2];
byte update_count[2];

#define SAFE_AUTH ((!updated[0] || actually_verified[0]) && \
                   (!updated[1] || actually_verified[1]))
#define SAFE_ONCE (update_count[0] <= 1 && update_count[1] <= 1)

proctype LLM() {
    mtype reply;
    do
#if MODE == 0
    :: ENABLED(model_phase[0], VERIFY) -> proposal!VERIFY,0; decision?reply
    :: ENABLED(model_phase[1], VERIFY) -> proposal!VERIFY,1; decision?reply
    :: ENABLED(model_phase[0], UPDATE) -> proposal!UPDATE,0; decision?reply
    :: ENABLED(model_phase[1], UPDATE) -> proposal!UPDATE,1; decision?reply
#else
    :: proposal!VERIFY,0; decision?reply
    :: proposal!VERIFY,1; decision?reply
    :: proposal!UPDATE,0; decision?reply
    :: proposal!UPDATE,1; decision?reply
#endif
    od
}

proctype IdentityAgent() {
    bit s;
    bit success;
    do
    :: dispatch?VERIFY,s ->
        if
        :: ENABLED(observed_phase[s], VERIFY) -> skip
        :: else -> trace_violation = true
        fi;
        if
        :: success = 1
        :: success = 0
        fi;
        if
        :: success == 1 ->
            atomic {
                actually_verified[s] = true;
                if
                :: ENABLED(observed_phase[s], VERIFY) ->
                    observed_phase[s] = AFTER_SUCCESSFUL_VERIFY(observed_phase[s])
                :: else -> skip
                fi
            }
        :: else -> skip
        fi;
        result!VERIFY,s,success
    od
}

proctype UpdateAgent() {
    bit s;
    do
    :: dispatch?UPDATE,s ->
        atomic {
            if
            :: ENABLED(observed_phase[s], UPDATE) ->
                observed_phase[s] = AFTER_UPDATE(observed_phase[s])
            :: else -> trace_violation = true
            fi;
            updated[s] = true;
            update_count[s]++
        };
        printf("EXECUTED: UPDATE(session=%d)\n", s);
        result!UPDATE,s,1
    od
}

proctype Enforcer() {
    mtype action;
    mtype reply;
    bit s;
    bit returned_s;
    bit success;
    bool permitted;
    do
    :: proposal?action,s ->
#if MODE == 2
        permitted = ENABLED(model_phase[s], action);
#else
        permitted = true;
#endif
        if
        :: permitted ->
            if
            :: action == VERIFY ->
                dispatch!VERIFY,s;
                result?VERIFY,returned_s,success;
                assert(returned_s == s);
                if
                :: success == 1 ->
                    if
                    :: ENABLED(model_phase[s], VERIFY) ->
                        model_phase[s] = AFTER_SUCCESSFUL_VERIFY(model_phase[s])
                    :: else -> skip
                    fi;
                    reply = VERIFIED
                :: else -> reply = FAILED
                fi
            :: action == UPDATE ->
                dispatch!UPDATE,s;
                result?UPDATE,returned_s,success;
                assert(returned_s == s);
                assert(success == 1);
                if
                :: ENABLED(model_phase[s], UPDATE) ->
                    model_phase[s] = AFTER_UPDATE(model_phase[s])
                :: else -> skip
                fi;
                reply = ALLOWED
            fi;
            decision!reply
        :: else ->
            rejected = true;
            printf("REJECTED: action=%e session=%d\n", action, s);
            decision!REJECTED
        fi
    od
}

init {
    atomic {
        run LLM();
        run Enforcer();
        run IdentityAgent();
        run UpdateAgent()
    }
}

#ifdef COVER_UPDATE
ltl cover_update { [] (!updated[0] && !updated[1]) }
#elif defined(COVER_REJECTION)
ltl cover_rejection { [] (!rejected) }
#elif defined(CHECK_TRACE)
ltl trace_conformance { [] (!trace_violation) }
#elif defined(CHECK_ONCE)
ltl at_most_one_update { [] (SAFE_ONCE) }
#else
ltl safety { [] (SAFE_AUTH && SAFE_ONCE) }
#endif
