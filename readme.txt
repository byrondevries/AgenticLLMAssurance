LLM_MODEL.pml is the Promela/SPIN model of the bounded account-recovery system in Section IV of "Design-Time Verification and Run-Time Assurance of LLM-Based Agentic Systems," reproducing the eight configurations in Table I.

Requirements: SPIN 6.5.1 and a C compiler. Run these commands from the directory containing LLM_MODEL.pml, in Table I order.

--- Reference composed model: verify both safety properties (expected errors: 0)
spin -DMODE=0 -run -a LLM_MODEL.pml

--- Arbitrary LLM with pass-through gateway: expose a safety violation (expected errors: 1)
spin -DMODE=1 -run -a LLM_MODEL.pml

--- Arbitrary LLM with transition-based enforcement: verify both safety properties (expected errors: 0)
spin -DMODE=2 -run -a LLM_MODEL.pml

--- Unenforced system: detect an invocation violating the reference automaton (expected errors: 1)
spin -DMODE=1 -DCHECK_TRACE -run -a LLM_MODEL.pml

--- Enforced system: verify conformance of executed interactions to the reference automaton (expected errors: 0)
spin -DMODE=2 -DCHECK_TRACE -run -a LLM_MODEL.pml

--- Enforced system: verify at most one executed update per session (expected errors: 0)
spin -DMODE=2 -DCHECK_ONCE -run -a LLM_MODEL.pml

--- Enforced system: demonstrate that an update is reachable (expected errors: 1)
spin -DMODE=2 -DCOVER_UPDATE -run -a LLM_MODEL.pml

--- Enforced system: demonstrate that a proposal can be rejected (expected errors: 1)
spin -DMODE=2 -DCOVER_REJECTION -run -a LLM_MODEL.pml

Note: The expected errors in the unenforced safety and trace checks indicate violations. The expected errors in the final two checks are intentional reachability witnesses, not safety failures.