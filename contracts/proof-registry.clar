;; NeutralNode: Proof-of-Neutrality for Critical Infrastructure

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-INVALID-INPUT (err u400))

;; Proof status codes
(define-constant PROOF-STATUS-PENDING u0)
(define-constant PROOF-STATUS-VERIFIED u1)
(define-constant PROOF-STATUS-INVALID u2)

;; Data Maps

;; Map to store detailed proof data
(define-map detailed-proofs
  { proof-id: uint }
  {
    provider-id: uint,
    session-id: uint,
    proof-data: (buff 1024),  ;; Actual proof data
    verification-status: uint,
    submission-time: uint,
    verifier: principal
  }
)

;; Variables
(define-data-var last-proof-id uint u0)

;; Private functions

;; Check if the caller is the contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Public functions

;; Register a new neutrality proof
(define-public (register-proof
                (provider-id uint)
                (session-id uint)
                (proof-data (buff 1024)))
  (let
    (
      (new-proof-id (+ (var-get last-proof-id) u1))
    )
    ;; Store the new proof
    (map-set detailed-proofs
      { proof-id: new-proof-id }
      {
        provider-id: provider-id,
        session-id: session-id,
        proof-data: proof-data,
        verification-status: PROOF-STATUS-PENDING,
        submission-time: block-height,
        verifier: tx-sender
      }
    )
    
    ;; Update the proof counter
    (var-set last-proof-id new-proof-id)
    
    ;; Return the new proof ID
    (ok new-proof-id)
  )
)

;; Read-only functions

;; Get proof details
(define-read-only (get-proof-details (proof-id uint))
  (map-get? detailed-proofs { proof-id: proof-id })
)

;; Get the last proof ID
(define-read-only (get-last-proof-id)
  (var-get last-proof-id)
)
