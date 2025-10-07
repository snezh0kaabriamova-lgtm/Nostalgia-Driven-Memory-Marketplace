;; Selective Amnesia Subscription Model
;; Premium service to temporarily forget embarrassing moments while preserving positive memories

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_SUBSCRIPTION (err u101))
(define-constant ERR_INVALID_MEMORY (err u102))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u103))
(define-constant ERR_MEMORY_NOT_FOUND (err u104))
(define-constant ERR_SUBSCRIPTION_EXPIRED (err u105))
(define-constant ERR_MEMORY_LOCKED (err u106))

;; Subscription tiers
(define-constant BASIC_TIER u1)
(define-constant PREMIUM_TIER u2)
(define-constant DELUXE_TIER u3)

;; Pricing (in micro-STX)
(define-constant BASIC_PRICE u1000000)
(define-constant PREMIUM_PRICE u3000000)
(define-constant DELUXE_PRICE u5000000)

;; Duration constants (in blocks)
(define-constant BASIC_DURATION u144)
(define-constant PREMIUM_DURATION u1008)
(define-constant DELUXE_DURATION u4320)

;; Data Variables
(define-data-var next-memory-id uint u1)
(define-data-var next-subscription-id uint u1)
(define-data-var contract-balance uint u0)

;; Data Maps
(define-map memories 
  uint 
  {
    owner: principal,
    content-hash: (buff 32),
    emotional-value: uint,
    memory-type: (string-ascii 20),
    creation-block: uint,
    is-suppressed: bool,
    suppression-expires: uint
  }
)

(define-map subscriptions 
  uint
  {
    subscriber: principal,
    tier: uint,
    start-block: uint,
    duration: uint,
    is-active: bool,
    memories-processed: uint,
    payment-amount: uint
  }
)

(define-map user-subscriptions 
  principal 
  uint
)

(define-map user-memory-count 
  principal 
  uint
)

(define-map suppressed-memories
  { user: principal, memory-id: uint }
  uint
)

(define-map user-preferences
  principal
  {
    suppress-embarrassing: bool,
    preserve-positive: bool,
    custom-keywords: (list 10 (string-ascii 20)),
    sensitivity-level: uint
  }
)

;; Private Functions
(define-private (get-subscription-price (tier uint))
  (if (is-eq tier BASIC_TIER)
    BASIC_PRICE
    (if (is-eq tier PREMIUM_TIER)
      PREMIUM_PRICE
      (if (is-eq tier DELUXE_TIER)
        DELUXE_PRICE
        u0))))

(define-private (get-subscription-duration (tier uint))
  (if (is-eq tier BASIC_TIER)
    BASIC_DURATION
    (if (is-eq tier PREMIUM_TIER)
      PREMIUM_DURATION
      (if (is-eq tier DELUXE_TIER)
        DELUXE_DURATION
        u0))))

(define-private (is-valid-tier (tier uint))
  (or (is-eq tier BASIC_TIER)
      (or (is-eq tier PREMIUM_TIER)
          (is-eq tier DELUXE_TIER))))

(define-private (is-subscription-active (subscription-id uint))
  (match (map-get? subscriptions subscription-id)
    subscription
    (let ((end-block (+ (get start-block subscription) (get duration subscription))))
      (and (get is-active subscription)
           (< stacks-block-height end-block)))
    false))

(define-private (calculate-suppression-end (tier uint))
  (+ stacks-block-height (get-subscription-duration tier)))

;; Public Functions

;; Create a new memory entry
(define-public (create-memory (content-hash (buff 32)) (emotional-value uint) (memory-type (string-ascii 20)))
  (let ((memory-id (var-get next-memory-id))
        (current-count (default-to u0 (map-get? user-memory-count tx-sender))))
    (begin
      (asserts! (or (is-eq memory-type "embarrassing") (is-eq memory-type "positive")) ERR_INVALID_MEMORY)
      (asserts! (<= emotional-value u1000) ERR_INVALID_MEMORY)
      
      (map-set memories memory-id
        {
          owner: tx-sender,
          content-hash: content-hash,
          emotional-value: emotional-value,
          memory-type: memory-type,
          creation-block: stacks-block-height,
          is-suppressed: false,
          suppression-expires: u0
        })
      
      (map-set user-memory-count tx-sender (+ current-count u1))
      (var-set next-memory-id (+ memory-id u1))
      
      (ok memory-id))))

;; Purchase a subscription
(define-public (purchase-subscription (tier uint))
  (let ((subscription-id (var-get next-subscription-id))
        (price (get-subscription-price tier))
        (duration (get-subscription-duration tier)))
    (begin
      (asserts! (is-valid-tier tier) ERR_INVALID_SUBSCRIPTION)
      (asserts! (>= (stx-get-balance tx-sender) price) ERR_INSUFFICIENT_PAYMENT)
      
      (try! (stx-transfer? price tx-sender CONTRACT_OWNER))
      
      (map-set subscriptions subscription-id
        {
          subscriber: tx-sender,
          tier: tier,
          start-block: stacks-block-height,
          duration: duration,
          is-active: true,
          memories-processed: u0,
          payment-amount: price
        })
      
      (map-set user-subscriptions tx-sender subscription-id)
      (var-set next-subscription-id (+ subscription-id u1))
      (var-set contract-balance (+ (var-get contract-balance) price))
      
      (ok subscription-id))))

;; Suppress an embarrassing memory (requires active subscription)
(define-public (suppress-memory (memory-id uint))
  (let ((memory (unwrap! (map-get? memories memory-id) ERR_MEMORY_NOT_FOUND))
        (user-sub-id (unwrap! (map-get? user-subscriptions tx-sender) ERR_INVALID_SUBSCRIPTION)))
    (begin
      (asserts! (is-eq (get owner memory) tx-sender) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get memory-type memory) "embarrassing") ERR_INVALID_MEMORY)
      (asserts! (not (get is-suppressed memory)) ERR_MEMORY_LOCKED)
      (asserts! (is-subscription-active user-sub-id) ERR_SUBSCRIPTION_EXPIRED)
      
      (let ((subscription (unwrap! (map-get? subscriptions user-sub-id) ERR_INVALID_SUBSCRIPTION))
            (suppression-end (calculate-suppression-end (get tier subscription))))
        (begin
          (map-set memories memory-id
            (merge memory {
              is-suppressed: true,
              suppression-expires: suppression-end
            }))
          
          (map-set suppressed-memories { user: tx-sender, memory-id: memory-id } suppression-end)
          
          (map-set subscriptions user-sub-id
            (merge subscription {
              memories-processed: (+ (get memories-processed subscription) u1)
            }))
          
          (ok true))))))

;; Restore a suppressed memory
(define-public (restore-memory (memory-id uint))
  (let ((memory (unwrap! (map-get? memories memory-id) ERR_MEMORY_NOT_FOUND)))
    (begin
      (asserts! (is-eq (get owner memory) tx-sender) ERR_UNAUTHORIZED)
      (asserts! (get is-suppressed memory) ERR_INVALID_MEMORY)
      
      (map-set memories memory-id
        (merge memory {
          is-suppressed: false,
          suppression-expires: u0
        }))
      
      (map-delete suppressed-memories { user: tx-sender, memory-id: memory-id })
      
      (ok true))))

;; Set user preferences for memory filtering
(define-public (set-preferences (suppress-embarrassing bool) (preserve-positive bool) 
                               (keywords (list 10 (string-ascii 20))) (sensitivity uint))
  (begin
    (asserts! (<= sensitivity u10) ERR_INVALID_MEMORY)
    (asserts! (>= sensitivity u1) ERR_INVALID_MEMORY)
    
    (map-set user-preferences tx-sender
      {
        suppress-embarrassing: suppress-embarrassing,
        preserve-positive: preserve-positive,
        custom-keywords: keywords,
        sensitivity-level: sensitivity
      })
    
    (ok true)))

;; Auto-restore expired suppressions
(define-public (auto-restore-expired (memory-id uint))
  (let ((memory (unwrap! (map-get? memories memory-id) ERR_MEMORY_NOT_FOUND)))
    (begin
      (asserts! (get is-suppressed memory) ERR_INVALID_MEMORY)
      (asserts! (>= stacks-block-height (get suppression-expires memory)) ERR_MEMORY_LOCKED)
      
      (map-set memories memory-id
        (merge memory {
          is-suppressed: false,
          suppression-expires: u0
        }))
      
      (map-delete suppressed-memories { user: (get owner memory), memory-id: memory-id })
      
      (ok true))))

;; Read-only functions

(define-read-only (get-memory (memory-id uint))
  (map-get? memories memory-id))

(define-read-only (get-subscription (subscription-id uint))
  (map-get? subscriptions subscription-id))

(define-read-only (get-user-subscription (user principal))
  (map-get? user-subscriptions user))

(define-read-only (get-user-preferences (user principal))
  (map-get? user-preferences user))

(define-read-only (is-memory-suppressed (memory-id uint))
  (match (map-get? memories memory-id)
    memory
    (and (get is-suppressed memory)
         (< stacks-block-height (get suppression-expires memory)))
    false))

(define-read-only (get-user-memory-count (user principal))
  (default-to u0 (map-get? user-memory-count user)))

(define-read-only (get-contract-balance)
  (var-get contract-balance))

(define-read-only (get-next-memory-id)
  (var-get next-memory-id))

(define-read-only (get-tier-price (tier uint))
  (get-subscription-price tier))

