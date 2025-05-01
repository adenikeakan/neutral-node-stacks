;; NeutralNode: Proof-of-Neutrality for Critical Infrastructure
;;
;; Added basic verification sessions

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-REGISTERED (err u409))
(define-constant ERR-INVALID-INPUT (err u400))
(define-constant ERR-VERIFICATION-FAILED (err u500))

;; Provider types
(define-constant PROVIDER-TYPE-CDN u1)      ;; Content Delivery Networks
(define-constant PROVIDER-TYPE-DNS u2)      ;; Domain Name Systems
(define-constant PROVIDER-TYPE-API u3)      ;; API Services
(define-constant PROVIDER-TYPE-CLOUD u4)    ;; Cloud Computing Providers
(define-constant PROVIDER-TYPE-ISP u5)      ;; Internet Service Providers
(define-constant PROVIDER-TYPE-OTHER u99)   ;; Other infrastructure types

;; Data Maps

;; Map to track registered infrastructure providers
(define-map providers
  { provider-id: uint }
  {
    name: (string-ascii 64),
    provider-principal: principal,
    provider-type: uint,
    registration-time: uint,
    active: bool,
    metadata-url: (optional (string-utf8 256))
  }
)

;; Map to track verification sessions - each session represents a period of monitoring
(define-map verification-sessions
  { session-id: uint }
  {
    provider-id: uint,
    start-time: uint,
    end-time: (optional uint),
    verifier-count: uint,
    status: uint,  ;; 0 = pending, 1 = active, 2 = completed, 3 = failed
    merkle-root: (optional (buff 32))
  }
)

;; Variables
(define-data-var last-provider-id uint u0)
(define-data-var last-session-id uint u0)

;; Private functions

;; Check if the caller is the contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Check if the caller is the registered provider for a given provider ID
(define-private (is-provider-owner (provider-id uint))
  (match (map-get? providers { provider-id: provider-id })
    provider (is-eq tx-sender (get provider-principal provider))
    false
  )
)

;; Check if a verification session exists and is in the expected status
(define-private (is-valid-session (session-id uint) (expected-status uint))
  (match (map-get? verification-sessions { session-id: session-id })
    session (is-eq (get status session) expected-status)
    false
  )
)

;; Public functions

;; Register a new infrastructure provider
(define-public (register-provider 
                (name (string-ascii 64))
                (provider-type uint)
                (metadata-url (optional (string-utf8 256))))
  (let
    (
      (new-provider-id (+ (var-get last-provider-id) u1))
    )
    ;; Ensure provider type is valid
    (asserts! (or 
                (is-eq provider-type PROVIDER-TYPE-CDN)
                (is-eq provider-type PROVIDER-TYPE-DNS)
                (is-eq provider-type PROVIDER-TYPE-API)
                (is-eq provider-type PROVIDER-TYPE-CLOUD)
                (is-eq provider-type PROVIDER-TYPE-ISP)
                (is-eq provider-type PROVIDER-TYPE-OTHER))
              ERR-INVALID-INPUT)
    
    ;; Save provider data
    (map-set providers
      { provider-id: new-provider-id }
      {
        name: name,
        provider-principal: tx-sender,
        provider-type: provider-type,
        registration-time: block-height,
        active: true,
        metadata-url: metadata-url
      }
    )
    
    ;; Update the provider counter
    (var-set last-provider-id new-provider-id)
    
    ;; Return the new provider ID
    (ok new-provider-id)
  )
)

;; Update provider information (only the provider can update their own info)
(define-public (update-provider
                (provider-id uint)
                (name (string-ascii 64))
                (provider-type uint)
                (metadata-url (optional (string-utf8 256)))
                (active bool))
  (begin
    ;; Check authorization
    (asserts! (is-provider-owner provider-id) ERR-NOT-AUTHORIZED)
    
    ;; Ensure provider exists
    (asserts! (is-some (map-get? providers { provider-id: provider-id })) ERR-NOT-FOUND)
    
    ;; Ensure provider type is valid
    (asserts! (or 
                (is-eq provider-type PROVIDER-TYPE-CDN)
                (is-eq provider-type PROVIDER-TYPE-DNS)
                (is-eq provider-type PROVIDER-TYPE-API)
                (is-eq provider-type PROVIDER-TYPE-CLOUD)
                (is-eq provider-type PROVIDER-TYPE-ISP)
                (is-eq provider-type PROVIDER-TYPE-OTHER))
              ERR-INVALID-INPUT)
    
    ;; Update provider data
    (map-set providers
      { provider-id: provider-id }
      {
        name: name,
        provider-principal: tx-sender,
        provider-type: provider-type,
        registration-time: (get registration-time (unwrap-panic (map-get? providers { provider-id: provider-id }))),
        active: active,
        metadata-url: metadata-url
      }
    )
    
    (ok true)
  )
)

;; Start a new verification session for a provider
(define-public (start-verification-session (provider-id uint))
  (let
    (
      (new-session-id (+ (var-get last-session-id) u1))
    )
    ;; Check authorization - for now only the provider can start a session
    (asserts! (is-provider-owner provider-id) ERR-NOT-AUTHORIZED)
    
    ;; Ensure provider exists and is active
    (match (map-get? providers { provider-id: provider-id })
      provider (asserts! (get active provider) ERR-INVALID-INPUT)
      (asserts! false ERR-NOT-FOUND)
    )
    
    ;; Create the new verification session
    (map-set verification-sessions
      { session-id: new-session-id }
      {
        provider-id: provider-id,
        start-time: block-height,
        end-time: none,
        verifier-count: u0,
        status: u1, ;; Active
        merkle-root: none
      }
    )
    
    ;; Update the session counter
    (var-set last-session-id new-session-id)
    
    ;; Return the new session ID
    (ok new-session-id)
  )
)

;; Read-only functions

;; Get provider information
(define-read-only (get-provider (provider-id uint))
  (map-get? providers { provider-id: provider-id })
)

;; Get verification session information
(define-read-only (get-verification-session (session-id uint))
  (map-get? verification-sessions { session-id: session-id })
)

;; Get the last provider ID
(define-read-only (get-last-provider-id)
  (var-get last-provider-id)
)

;; Get the last session ID
(define-read-only (get-last-session-id)
  (var-get last-session-id)
)
