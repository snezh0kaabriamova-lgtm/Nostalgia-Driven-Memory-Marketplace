;; Synthetic Childhood Experience Generator
;; Creates false but comforting memories for adults who had suboptimal upbringings

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_EXPERIENCE (err u201))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u202))
(define-constant ERR_EXPERIENCE_NOT_FOUND (err u203))
(define-constant ERR_QUALITY_CHECK_FAILED (err u204))
(define-constant ERR_ALREADY_EXISTS (err u205))
(define-constant ERR_INVALID_PARAMETERS (err u206))
(define-constant ERR_GENERATION_LIMIT_REACHED (err u207))

;; Experience categories
(define-constant FAMILY_BONDING u1)
(define-constant ACHIEVEMENTS u2)
(define-constant COMFORT_MOMENTS u3)
(define-constant SOCIAL_ACCEPTANCE u4)
(define-constant LEARNING_JOY u5)
(define-constant HOLIDAY_MEMORIES u6)

;; Quality levels
(define-constant BASIC_QUALITY u1)
(define-constant PREMIUM_QUALITY u2)
(define-constant THERAPEUTIC_QUALITY u3)

;; Pricing (in micro-STX)
(define-constant BASIC_EXPERIENCE_PRICE u500000)
(define-constant PREMIUM_EXPERIENCE_PRICE u2000000)
(define-constant THERAPEUTIC_EXPERIENCE_PRICE u5000000)

;; Therapeutic value thresholds
(define-constant MIN_THERAPEUTIC_VALUE u500)
(define-constant MAX_THERAPEUTIC_VALUE u1000)

;; Generation limits
(define-constant DAILY_GENERATION_LIMIT u5)
(define-constant MAX_USER_EXPERIENCES u50)

;; Data Variables
(define-data-var next-experience-id uint u1)
(define-data-var total-experiences-generated uint u0)
(define-data-var contract-revenue uint u0)
(define-data-var quality-threshold uint u700)

;; Data Maps
(define-map synthetic-experiences 
  uint
  {
    owner: principal,
    category: uint,
    quality-level: uint,
    emotional-impact: uint,
    therapeutic-value: uint,
    content-template: (string-ascii 200),
    personalization-data: (string-ascii 100),
    creation-timestamp: uint,
    is-validated: bool,
    validation-score: uint,
    integration-status: (string-ascii 20)
  }
)

(define-map user-experience-collections
  principal
  {
    total-experiences: uint,
    favorite-category: uint,
    therapeutic-progress: uint,
    last-generation-block: uint,
    daily-count: uint,
    quality-preference: uint
  }
)

(define-map experience-templates
  { category: uint, quality: uint }
  {
    base-template: (string-ascii 200),
    emotional-weight: uint,
    therapeutic-benefit: uint,
    customization-points: (list 5 (string-ascii 30)),
    price: uint
  }
)

(define-map user-preferences
  principal
  {
    preferred-categories: (list 6 uint),
    emotional-intensity: uint,
    therapeutic-focus: (string-ascii 50),
    personalization-level: uint,
    integration-speed: uint
  }
)

(define-map quality-validators
  principal
  {
    is-active: bool,
    validations-completed: uint,
    accuracy-score: uint,
    rewards-earned: uint
  }
)

(define-map experience-reviews
  { experience-id: uint, reviewer: principal }
  {
    quality-score: uint,
    therapeutic-effectiveness: uint,
    authenticity-rating: uint,
    review-timestamp: uint,
    comments: (string-ascii 100)
  }
)

;; Private Functions
(define-private (get-experience-price (quality uint))
  (if (is-eq quality BASIC_QUALITY)
    BASIC_EXPERIENCE_PRICE
    (if (is-eq quality PREMIUM_QUALITY)
      PREMIUM_EXPERIENCE_PRICE
      (if (is-eq quality THERAPEUTIC_QUALITY)
        THERAPEUTIC_EXPERIENCE_PRICE
        u0))))

(define-private (is-valid-category (category uint))
  (and (>= category u1) (<= category u6)))

(define-private (is-valid-quality (quality uint))
  (and (>= quality u1) (<= quality u3)))

(define-private (calculate-therapeutic-value (category uint) (quality uint) (emotional-impact uint))
  (let ((base-value (* category u50))
        (quality-bonus (* quality u100))
        (impact-bonus emotional-impact))
    (if (<= (+ base-value quality-bonus impact-bonus) MAX_THERAPEUTIC_VALUE)
      (+ base-value quality-bonus impact-bonus)
      MAX_THERAPEUTIC_VALUE)))

(define-private (check-daily-limit (user principal))
  (let ((user-collection (default-to 
                          { total-experiences: u0, favorite-category: u1, therapeutic-progress: u0, 
                            last-generation-block: u0, daily-count: u0, quality-preference: u1 } 
                          (map-get? user-experience-collections user))))
    (if (is-eq (get last-generation-block user-collection) stacks-block-height)
      (< (get daily-count user-collection) DAILY_GENERATION_LIMIT)
      true)))

(define-private (update-daily-count (user principal))
  (let ((user-collection (default-to 
                          { total-experiences: u0, favorite-category: u1, therapeutic-progress: u0, 
                            last-generation-block: u0, daily-count: u0, quality-preference: u1 } 
                          (map-get? user-experience-collections user))))
    (if (is-eq (get last-generation-block user-collection) stacks-block-height)
      (map-set user-experience-collections user
        (merge user-collection {
          daily-count: (+ (get daily-count user-collection) u1)
        }))
      (map-set user-experience-collections user
        (merge user-collection {
          last-generation-block: stacks-block-height,
          daily-count: u1
        })))))

(define-private (generate-quality-score (category uint) (quality uint) (personalization (string-ascii 100)))
  (let ((base-score (* category u100))
        (quality-multiplier quality)
        (personalization-bonus (len personalization)))
    (if (<= (+ (* base-score quality-multiplier) personalization-bonus) u1000)
      (+ (* base-score quality-multiplier) personalization-bonus)
      u1000)))

;; Public Functions

;; Generate a new synthetic childhood experience
(define-public (generate-experience (category uint) (quality uint) (emotional-impact uint) 
                                   (personalization (string-ascii 100)))
  (let ((experience-id (var-get next-experience-id))
        (price (get-experience-price quality))
        (user-collection (default-to 
                          { total-experiences: u0, favorite-category: u1, therapeutic-progress: u0, 
                            last-generation-block: u0, daily-count: u0, quality-preference: u1 } 
                          (map-get? user-experience-collections tx-sender))))
    (begin
      (asserts! (is-valid-category category) ERR_INVALID_PARAMETERS)
      (asserts! (is-valid-quality quality) ERR_INVALID_PARAMETERS)
      (asserts! (<= emotional-impact u1000) ERR_INVALID_PARAMETERS)
      (asserts! (>= (stx-get-balance tx-sender) price) ERR_INSUFFICIENT_PAYMENT)
      (asserts! (check-daily-limit tx-sender) ERR_GENERATION_LIMIT_REACHED)
      (asserts! (< (get total-experiences user-collection) MAX_USER_EXPERIENCES) ERR_GENERATION_LIMIT_REACHED)
      
      (try! (stx-transfer? price tx-sender CONTRACT_OWNER))
      
      (let ((therapeutic-value (calculate-therapeutic-value category quality emotional-impact))
            (content-template (default-to "Custom childhood memory experience" 
                               (get base-template (map-get? experience-templates { category: category, quality: quality }))))
            (validation-score (generate-quality-score category quality personalization)))
        (begin
          (map-set synthetic-experiences experience-id
            {
              owner: tx-sender,
              category: category,
              quality-level: quality,
              emotional-impact: emotional-impact,
              therapeutic-value: therapeutic-value,
              content-template: content-template,
              personalization-data: personalization,
              creation-timestamp: stacks-block-height,
              is-validated: false,
              validation-score: validation-score,
              integration-status: "pending"
            })
          
          (map-set user-experience-collections tx-sender
            (merge user-collection {
              total-experiences: (+ (get total-experiences user-collection) u1),
              therapeutic-progress: (+ (get therapeutic-progress user-collection) therapeutic-value)
            }))
          
          (update-daily-count tx-sender)
          
          (var-set next-experience-id (+ experience-id u1))
          (var-set total-experiences-generated (+ (var-get total-experiences-generated) u1))
          (var-set contract-revenue (+ (var-get contract-revenue) price))
          
          (ok experience-id))))))

;; Validate an experience (for quality assurance)
(define-public (validate-experience (experience-id uint) (quality-score uint) (therapeutic-score uint))
  (let ((experience (unwrap! (map-get? synthetic-experiences experience-id) ERR_EXPERIENCE_NOT_FOUND))
        (validator (default-to { is-active: false, validations-completed: u0, accuracy-score: u0, rewards-earned: u0 }
                               (map-get? quality-validators tx-sender))))
    (begin
      (asserts! (get is-active validator) ERR_UNAUTHORIZED)
      (asserts! (<= quality-score u1000) ERR_INVALID_PARAMETERS)
      (asserts! (<= therapeutic-score u1000) ERR_INVALID_PARAMETERS)
      (asserts! (not (get is-validated experience)) ERR_ALREADY_EXISTS)
      
      (map-set synthetic-experiences experience-id
        (merge experience {
          is-validated: true,
          validation-score: quality-score,
          integration-status: (if (>= quality-score (var-get quality-threshold)) "integrated" "rejected")
        }))
      
      (map-set quality-validators tx-sender
        (merge validator {
          validations-completed: (+ (get validations-completed validator) u1),
          accuracy-score: (+ (get accuracy-score validator) quality-score),
          rewards-earned: (+ (get rewards-earned validator) u10000)
        }))
      
      (ok true))))

;; Integrate validated experience into user's memory collection
(define-public (integrate-experience (experience-id uint))
  (let ((experience (unwrap! (map-get? synthetic-experiences experience-id) ERR_EXPERIENCE_NOT_FOUND)))
    (begin
      (asserts! (is-eq (get owner experience) tx-sender) ERR_UNAUTHORIZED)
      (asserts! (get is-validated experience) ERR_QUALITY_CHECK_FAILED)
      (asserts! (is-eq (get integration-status experience) "integrated") ERR_QUALITY_CHECK_FAILED)
      
      (map-set synthetic-experiences experience-id
        (merge experience {
          integration-status: "completed"
        }))
      
      (ok true))))

;; Set user preferences for experience generation
(define-public (set-user-preferences (categories (list 6 uint)) (emotional-intensity uint) 
                                    (therapeutic-focus (string-ascii 50)) (personalization-level uint) 
                                    (integration-speed uint))
  (begin
    (asserts! (<= emotional-intensity u10) ERR_INVALID_PARAMETERS)
    (asserts! (>= emotional-intensity u1) ERR_INVALID_PARAMETERS)
    (asserts! (<= personalization-level u10) ERR_INVALID_PARAMETERS)
    (asserts! (>= personalization-level u1) ERR_INVALID_PARAMETERS)
    
    (map-set user-preferences tx-sender
      {
        preferred-categories: categories,
        emotional-intensity: emotional-intensity,
        therapeutic-focus: therapeutic-focus,
        personalization-level: personalization-level,
        integration-speed: integration-speed
      })
    
    (ok true)))

;; Register as a quality validator
(define-public (register-validator)
  (let ((existing-validator (map-get? quality-validators tx-sender)))
    (begin
      (asserts! (is-none existing-validator) ERR_ALREADY_EXISTS)
      
      (map-set quality-validators tx-sender
        {
          is-active: true,
          validations-completed: u0,
          accuracy-score: u0,
          rewards-earned: u0
        })
      
      (ok true))))

;; Submit experience review
(define-public (submit-review (experience-id uint) (quality-score uint) (therapeutic-effectiveness uint) 
                             (authenticity-rating uint) (comments (string-ascii 100)))
  (let ((experience (unwrap! (map-get? synthetic-experiences experience-id) ERR_EXPERIENCE_NOT_FOUND)))
    (begin
      (asserts! (is-eq (get integration-status experience) "completed") ERR_QUALITY_CHECK_FAILED)
      (asserts! (<= quality-score u1000) ERR_INVALID_PARAMETERS)
      (asserts! (<= therapeutic-effectiveness u1000) ERR_INVALID_PARAMETERS)
      (asserts! (<= authenticity-rating u1000) ERR_INVALID_PARAMETERS)
      
      (map-set experience-reviews { experience-id: experience-id, reviewer: tx-sender }
        {
          quality-score: quality-score,
          therapeutic-effectiveness: therapeutic-effectiveness,
          authenticity-rating: authenticity-rating,
          review-timestamp: stacks-block-height,
          comments: comments
        })
      
      (ok true))))

;; Purchase a pre-made experience template
(define-public (purchase-template (category uint) (quality uint))
  (let ((template-key { category: category, quality: quality })
        (template (unwrap! (map-get? experience-templates template-key) ERR_EXPERIENCE_NOT_FOUND))
        (price (get price template)))
    (begin
      (asserts! (>= (stx-get-balance tx-sender) price) ERR_INSUFFICIENT_PAYMENT)
      
      (try! (stx-transfer? price tx-sender CONTRACT_OWNER))
      
      (generate-experience category quality (get emotional-weight template) "Template-based experience"))))

;; Read-only functions

(define-read-only (get-experience (experience-id uint))
  (map-get? synthetic-experiences experience-id))

(define-read-only (get-user-collection (user principal))
  (map-get? user-experience-collections user))

(define-read-only (get-user-preferences (user principal))
  (map-get? user-preferences user))

(define-read-only (get-validator-info (validator principal))
  (map-get? quality-validators validator))

(define-read-only (get-experience-template (category uint) (quality uint))
  (map-get? experience-templates { category: category, quality: quality }))

(define-read-only (get-experience-review (experience-id uint) (reviewer principal))
  (map-get? experience-reviews { experience-id: experience-id, reviewer: reviewer }))

(define-read-only (get-contract-stats)
  {
    total-experiences: (var-get total-experiences-generated),
    contract-revenue: (var-get contract-revenue),
    quality-threshold: (var-get quality-threshold),
    next-experience-id: (var-get next-experience-id)
  })

(define-read-only (can-generate-today (user principal))
  (check-daily-limit user))

(define-read-only (get-price-by-quality (quality uint))
  (get-experience-price quality))

(define-read-only (calculate-therapeutic-benefit (category uint) (quality uint) (emotional-impact uint))
  (calculate-therapeutic-value category quality emotional-impact))

