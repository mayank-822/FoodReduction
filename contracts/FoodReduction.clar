;; Food Waste Reduction Contract
;; Connect surplus food producers with consumers and food banks to minimize waste

(define-fungible-token food-reward-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-listing-not-found (err u103))
(define-constant err-insufficient-quantity (err u104))
(define-constant err-invalid-expiry (err u105))

;; Data structures
(define-map food-listings
  uint
  {
    producer: principal,
    food-type: (string-ascii 50),
    quantity: uint,
    expiry-date: uint,
    location: (string-ascii 100),
    price-per-unit: uint,
    is-active: bool
  })

(define-map user-profiles
  principal
  {
    user-type: (string-ascii 20), ;; "producer", "consumer", "food-bank"
    reputation-score: uint,
    total-donations: uint,
    total-claims: uint
  })

;; Data variables
(define-data-var next-listing-id uint u1)
(define-data-var total-food-saved uint u0)
(define-data-var reward-rate uint u10) ;; 10 tokens per kg saved

;; Function 1: List surplus food (for producers)
(define-public (list-surplus-food 
  (food-type (string-ascii 50))
  (quantity uint)
  (expiry-date uint)
  (location (string-ascii 100))
  (price-per-unit uint))
  (let ((listing-id (var-get next-listing-id))
        (current-block stacks-block-height))
    (begin
      (asserts! (> quantity u0) err-invalid-amount)
      (asserts! (> expiry-date current-block) err-invalid-expiry)

      (map-set food-listings listing-id
        {
          producer: tx-sender,
          food-type: food-type,
          quantity: quantity,
          expiry-date: expiry-date,
          location: location,
          price-per-unit: price-per-unit,
          is-active: true
        })

      (match (map-get? user-profiles tx-sender)
        existing-profile
          (map-set user-profiles tx-sender {
            user-type: (get user-type existing-profile),
            reputation-score: (get reputation-score existing-profile),
            total-donations: (+ (get total-donations existing-profile) quantity),
            total-claims: (get total-claims existing-profile)
          })
        (map-set user-profiles tx-sender
          {
            user-type: "producer",
            reputation-score: u100,
            total-donations: quantity,
            total-claims: u0
          }))

      (var-set next-listing-id (+ listing-id u1))

      (try! (ft-mint? food-reward-token (* quantity (var-get reward-rate)) tx-sender))

      (ok listing-id)
)))

;; Function 2: Claim food (for consumers and food banks)
(define-public (claim-food (listing-id uint) (requested-quantity uint))
  (let ((listing (unwrap! (map-get? food-listings listing-id) err-listing-not-found))
        (current-block stacks-block-height))
    (begin
      (asserts! (get is-active listing) err-listing-not-found)
      (asserts! (< current-block (get expiry-date listing)) err-invalid-expiry)
      (asserts! (> requested-quantity u0) err-invalid-amount)
      (asserts! (<= requested-quantity (get quantity listing)) err-insufficient-quantity)

      (let ((user-profile (map-get? user-profiles tx-sender))
            (is-food-bank (match user-profile 
                              profile (is-eq (get user-type profile) "food-bank")
                              false))
            (discount-rate (if is-food-bank u50 u100))
            (total-cost (/ (* requested-quantity (get price-per-unit listing) discount-rate) u100)))

        (if (> total-cost u0)
            (try! (stx-transfer? total-cost tx-sender (get producer listing)))
            true)

        (let ((remaining-quantity (- (get quantity listing) requested-quantity)))
          (if (is-eq remaining-quantity u0)
              (map-set food-listings listing-id {
                producer: (get producer listing),
                food-type: (get food-type listing),
                quantity: u0,
                expiry-date: (get expiry-date listing),
                location: (get location listing),
                price-per-unit: (get price-per-unit listing),
                is-active: false
              })
              (map-set food-listings listing-id {
                producer: (get producer listing),
                food-type: (get food-type listing),
                quantity: remaining-quantity,
                expiry-date: (get expiry-date listing),
                location: (get location listing),
                price-per-unit: (get price-per-unit listing),
                is-active: true
              })))

        (match (map-get? user-profiles tx-sender)
          existing-profile
            (map-set user-profiles tx-sender {
              user-type: (get user-type existing-profile),
              reputation-score: (get reputation-score existing-profile),
              total-donations: (get total-donations existing-profile),
              total-claims: (+ (get total-claims existing-profile) requested-quantity)
            })
          (map-set user-profiles tx-sender
            {
              user-type: (if is-food-bank "food-bank" "consumer"),
              reputation-score: u100,
              total-donations: u0,
              total-claims: requested-quantity
            }))

        (var-set total-food-saved (+ (var-get total-food-saved) requested-quantity))

        (try! (ft-mint? food-reward-token (* requested-quantity u5) tx-sender))

        (ok {claimed-quantity: requested-quantity,
             remaining-quantity: (- (get quantity listing) requested-quantity)})
))))
;; Read-only functions
(define-read-only (get-food-listing (listing-id uint))
  (ok (map-get? food-listings listing-id)))

(define-read-only (get-user-profile (user principal))
  (ok (map-get? user-profiles user)))

(define-read-only (get-total-food-saved)
  (ok (var-get total-food-saved)))

(define-read-only (get-reward-balance (user principal))
  (ok (ft-get-balance food-reward-token user)))
