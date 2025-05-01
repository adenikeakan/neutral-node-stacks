;; NeutralNode: Proof-of-Neutrality for Critical Infrastructure

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-REGISTERED (err u409))
(define-constant ERR-INVALID-INPUT (err u400))

;; Proof status codes
(define-constant PROOF-STATUS-PENDING u0)
(define-constant PROOF-STATUS-VERIFIED u1)
(define-constant PROOF-STATUS-INVALID u2)

;; Proof types - Different verification approaches
(define-constant PROOF-TYPE-MERKLE u1)        ;; Merkle tree inclusion proofs
(define-constant PROOF-TYPE-ZK-SNARK u2)      ;; Zero-knowledge SNARKs
(define-constant PROOF-TYPE-HASH-COMPARE u3)  ;; Hash comparison proofs
(define-constant PROOF-TYPE-SIGNATURE u4)     ;; Digital signature verification

;; Data Maps

;; Map to store detailed proof data
(define-map detailed-proofs
  { proof-id: uint }
  {
    provider-id: uint,
    session-id: uint,
    proof-type: uint,
    proof-data: (buff 1024),  ;; Actual proof data
    verification-status: uint,
    submission-time: uint,
    verification-time: (optional uint),
    verifier: principal,
    metadata: (optional (string-utf8 256))
  }
)

;; Variables
(define-data-var last-proof-id uint u0)

;; Private functions

;; Check if the caller is the contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Validate that a proof exists and is in the expected status
(define-private (is-valid-proof (proof-id uint) (expected-status uint))
  (match (map-get? detailed-proofs { proof-id: proof-id })
    proof (is-eq (get verification-status proof) expected-status)
    false
  )
)

;; Public functions

;; Register a new neutrality proof
(define-public (register-proof
                (provider-id uint)
                (session-id uint)
                (proof-type uint)
                (proof-data (buff 1024))
                (metadata (optional (string-utf8 256))))
  (let
    (
      (new-proof-id (+ (var-get last-proof-id) u1))
    )
    ;; Ensure proof type is valid
    (asserts! (or 
                (is-eq proof-type PROOF-TYPE-MERKLE)
                (is-eq proof-type PROOF-TYPE-ZK-SNARK)
                (is-eq proof-type PROOF-TYPE-HASH-COMPARE)
                (is-eq proof-type PROOF-TYPE-SIGNATURE))
              ERR-INVALID-INPUT)
    
    ;; Store the new proof
    (map-set detailed-proofs
      { proof-id: new-proof-id }
      {
        provider-id: provider-id,
        session-id: session-id,
        proof-type: proof-type,
        proof-data: proof-data,
        verification-status: PROOF-STATUS-PENDING,
        submission-time: block-height,
        verification-time: none,
        verifier: tx-sender,
        metadata: metadata
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
