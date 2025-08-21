;; Title: SatoshiLink Bridge Contract
;; Summary:
;; SatoshiLink is a cross-chain asset bridge that provides secure,
;; validator-governed transfers between Bitcoin and the Stacks
;; blockchain. It ensures compliance, trust minimization, and
;; transparency in bridging activities.
;;
;; Description:
;; The SatoshiLink Bridge contract is designed to enable safe and 
;; auditable asset transfers from Bitcoin into the Stacks ecosystem 
;; and vice versa. Validators authorize deposits and withdrawals, 
;; ensuring that each cross-chain action is properly verified. 
;; Built with layered security checks, validator signature 
;; requirements, and withdrawal controls, SatoshiLink ensures 
;; Bitcoin-Stacks interoperability without compromising integrity. 
;; The contract includes functionality for deposit initiation, 
;; signature confirmations, validator management, balance tracking, 
;; emergency withdrawals, and strict validation of Bitcoin-related 
;; parameters. 
;;
;; Key Highlights:
;; - Validator-driven deposit confirmations
;; - Safe pause/resume mechanisms for incident response
;; - Robust validation of BTC addresses, tx-hashes, and signatures
;; - Transparent logging of withdrawals for off-chain processing
;; - Emergency controls for deployer in critical events

;; Traits
(define-trait bridgeable-token-trait (
  (transfer
    (uint principal principal)
    (response bool uint)
  )
  (get-balance
    (principal)
    (response uint uint)
  )
))

;; Constants

;; Error codes
(define-constant ERROR-NOT-AUTHORIZED u1000)
(define-constant ERROR-INVALID-AMOUNT u1001)
(define-constant ERROR-INSUFFICIENT-BALANCE u1002)
(define-constant ERROR-INVALID-BRIDGE-STATUS u1003)
(define-constant ERROR-INVALID-SIGNATURE u1004)
(define-constant ERROR-ALREADY-PROCESSED u1005)
(define-constant ERROR-BRIDGE-PAUSED u1006)
(define-constant ERROR-INVALID-VALIDATOR-ADDRESS u1007)
(define-constant ERROR-INVALID-RECIPIENT-ADDRESS u1008)
(define-constant ERROR-INVALID-BTC-ADDRESS u1009)
(define-constant ERROR-INVALID-TX-HASH u1010)
(define-constant ERROR-INVALID-SIGNATURE-FORMAT u1011)

;; System constants
(define-constant CONTRACT-DEPLOYER tx-sender)
(define-constant MIN-DEPOSIT-AMOUNT u100000) ;; Minimum BTC amount (sats)
(define-constant MAX-DEPOSIT-AMOUNT u1000000000) ;; Maximum BTC amount (sats)
(define-constant REQUIRED-CONFIRMATIONS u6) ;; Validator confirmations needed

;; Data Variables
(define-data-var bridge-paused bool false)
(define-data-var total-bridged-amount uint u0)
(define-data-var last-processed-height uint u0)

;; Data Maps

;; Records deposits by Bitcoin tx-hash
(define-map deposits
  { tx-hash: (buff 32) }
  {
    amount: uint,
    recipient: principal,
    processed: bool,
    confirmations: uint,
    timestamp: uint,
    btc-sender: (buff 33),
  }
)

;; Validator registry
(define-map validators
  principal
  bool
)

;; Validator signatures for deposits
(define-map validator-signatures
  {
    tx-hash: (buff 32),
    validator: principal,
  }
  {
    signature: (buff 65),
    timestamp: uint,
  }
)

;; Bridge balances per user
(define-map bridge-balances
  principal
  uint
)

;; Public Functions

;; Initialize bridge (only deployer)
(define-public (initialize-bridge)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-DEPLOYER) (err ERROR-NOT-AUTHORIZED))
    (var-set bridge-paused false)
    (ok true)
  )
)

;; Pause bridge operations (only deployer)
(define-public (pause-bridge)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-DEPLOYER) (err ERROR-NOT-AUTHORIZED))
    (var-set bridge-paused true)
    (ok true)
  )
)

;; Resume bridge (only deployer)
(define-public (resume-bridge)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-DEPLOYER) (err ERROR-NOT-AUTHORIZED))
    (asserts! (var-get bridge-paused) (err ERROR-INVALID-BRIDGE-STATUS))
    (var-set bridge-paused false)
    (ok true)
  )
)

;; Add validator (only deployer)
(define-public (add-validator (validator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-DEPLOYER) (err ERROR-NOT-AUTHORIZED))
    (asserts! (is-valid-principal validator)
      (err ERROR-INVALID-VALIDATOR-ADDRESS)
    )
    (map-set validators validator true)
    (ok true)
  )
)

;; Remove validator (only deployer)
(define-public (remove-validator (validator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-DEPLOYER) (err ERROR-NOT-AUTHORIZED))
    (asserts! (is-valid-principal validator)
      (err ERROR-INVALID-VALIDATOR-ADDRESS)
    )
    (map-set validators validator false)
    (ok true)
  )
)

;; Initiate a Bitcoin deposit (validator-only)
(define-public (initiate-deposit
    (tx-hash (buff 32))
    (amount uint)
    (recipient principal)
    (btc-sender (buff 33))
  )
  (begin
    (asserts! (not (var-get bridge-paused)) (err ERROR-BRIDGE-PAUSED))
    (asserts! (validate-deposit-amount amount) (err ERROR-INVALID-AMOUNT))
    (asserts! (get-validator-status tx-sender) (err ERROR-NOT-AUTHORIZED))
    (asserts! (is-valid-tx-hash tx-hash) (err ERROR-INVALID-TX-HASH))
    (asserts! (is-none (map-get? deposits { tx-hash: tx-hash }))
      (err ERROR-ALREADY-PROCESSED)
    )
    (asserts! (is-valid-principal recipient)
      (err ERROR-INVALID-RECIPIENT-ADDRESS)
    )
    (asserts! (is-valid-btc-address btc-sender) (err ERROR-INVALID-BTC-ADDRESS))

    (let ((validated-deposit {
        amount: amount,
        recipient: recipient,
        processed: false,
        confirmations: u0,
        timestamp: stacks-block-height,
        btc-sender: btc-sender,
      }))
      (map-set deposits { tx-hash: tx-hash } validated-deposit)
      (ok true)
    )
  )
)

;; Confirm deposit (validator-only)
(define-public (confirm-deposit
    (tx-hash (buff 32))
    (signature (buff 65))
  )
  (let (
      (deposit (unwrap! (map-get? deposits { tx-hash: tx-hash })
        (err ERROR-INVALID-BRIDGE-STATUS)
      ))
      (is-validator (get-validator-status tx-sender))
    )
    (asserts! (not (var-get bridge-paused)) (err ERROR-BRIDGE-PAUSED))
    (asserts! (is-valid-tx-hash tx-hash) (err ERROR-INVALID-TX-HASH))
    (asserts! (is-valid-signature signature) (err ERROR-INVALID-SIGNATURE-FORMAT))
    (asserts! (not (get processed deposit)) (err ERROR-ALREADY-PROCESSED))
    (asserts! (>= (get confirmations deposit) REQUIRED-CONFIRMATIONS)
      (err ERROR-INVALID-BRIDGE-STATUS)
    )
    (asserts!
      (is-none (map-get? validator-signatures {
        tx-hash: tx-hash,
        validator: tx-sender,
      }))
      (err ERROR-ALREADY-PROCESSED)
    )

    (let ((validated-signature {
        signature: signature,
        timestamp: stacks-block-height,
      }))
      (map-set validator-signatures {
        tx-hash: tx-hash,
        validator: tx-sender,
      }
        validated-signature
      )
      (map-set deposits { tx-hash: tx-hash } (merge deposit { processed: true }))
      (map-set bridge-balances (get recipient deposit)
        (+ (default-to u0 (map-get? bridge-balances (get recipient deposit)))
          (get amount deposit)
        ))
      (var-set total-bridged-amount
        (+ (var-get total-bridged-amount) (get amount deposit))
      )
      (ok true)
    )
  )
)

;; Withdraw from bridge to a Bitcoin address
(define-public (withdraw
    (amount uint)
    (btc-recipient (buff 34))
  )
  (let ((current-balance (get-bridge-balance tx-sender)))
    (asserts! (not (var-get bridge-paused)) (err ERROR-BRIDGE-PAUSED))
    (asserts! (>= current-balance amount) (err ERROR-INSUFFICIENT-BALANCE))
    (asserts! (validate-deposit-amount amount) (err ERROR-INVALID-AMOUNT))

    (map-set bridge-balances tx-sender (- current-balance amount))

    (print {
      type: "withdraw",
      sender: tx-sender,
      amount: amount,
      btc-recipient: btc-recipient,
      timestamp: stacks-block-height,
    })

    (var-set total-bridged-amount (- (var-get total-bridged-amount) amount))
    (ok true)
  )
)

;; Emergency withdraw (deployer-only)
(define-public (emergency-withdraw
    (amount uint)
    (recipient principal)
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT-DEPLOYER) (err ERROR-NOT-AUTHORIZED))
    (asserts! (>= (var-get total-bridged-amount) amount)
      (err ERROR-INSUFFICIENT-BALANCE)
    )
    (asserts! (is-valid-principal recipient)
      (err ERROR-INVALID-RECIPIENT-ADDRESS)
    )

    (let (
        (current-balance (default-to u0 (map-get? bridge-balances recipient)))
        (new-balance (+ current-balance amount))
      )
      (asserts! (> new-balance current-balance) (err ERROR-INVALID-AMOUNT))
      (map-set bridge-balances recipient new-balance)
      (ok true)
    )
  )
)