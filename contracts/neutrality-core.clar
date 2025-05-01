;; NeutralNode: Proof-of-Neutrality for Critical Infrastructure
;;
;; Provider registration and management

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-REGISTERED (err u409))
(define-constant ERR-INVALID-INPUT (err u400))

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

;; Variables
(define-data-var last-provider-id uint u0)

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

;; Read-only functions

;; Get provider information
(define-read-only (get-provider (provider-id uint))
  (map-get? providers { provider-id: provider-id })
)

;; Get the last provider ID
(define-read-only (get-last-provider-id)
  (var-get last-provider-id)
)
