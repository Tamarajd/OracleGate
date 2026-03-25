;; contract title 
;; Machine Learning-Powered Token Gating (Extended)

;; <add a description here> 
;; This contract integrates off-chain Machine Learning intelligence for on-chain token gating.
;; An authorized ML oracle analyzes user wallet history, behaviors, and risk profiles off-chain,
;; and assigns an ML confidence score to the user on-chain.
;; Users whose ML score meets or exceeds defined thresholds can mint gated NFT tokens.
;; The contract ensures secure token issuance and provides an asynchronous ML evaluation request system.
;; It also includes advanced features like tiered minting, blacklisting, token revocation,
;; and administrative controls for pausing and updating fees.

;; constants 
(define-constant contract-owner tx-sender)

;; Error Codes
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized-oracle (err u101))
(define-constant err-score-too-low (err u102))
(define-constant err-already-minted (err u103))
(define-constant err-request-pending (err u104))
(define-constant err-no-request (err u105))
(define-constant err-not-pending (err u106))
(define-constant err-paused (err u107))
(define-constant err-blacklisted (err u108))
(define-constant err-invalid-tier (err u109))
(define-constant err-not-token-owner (err u110))

;; ML Score Thresholds for Tiers
(define-constant tier-1-threshold u50)  ;; Bronze
(define-constant tier-2-threshold u75)  ;; Silver
(define-constant tier-3-threshold u90)  ;; Gold

;; data maps and vars 
;; Authorized ML Oracle capable of setting user scores
(define-data-var ml-oracle principal tx-sender)
;; The recipient of the evaluation fees
(define-data-var evaluation-fee-recipient principal contract-owner)
;; The current NFT ID counter
(define-data-var nft-id-nonce uint u0)
;; The fee required to request an asynchronous ML evaluation (in micro-STX)
(define-data-var evaluation-fee uint u1000000)
;; Contract pause state
(define-data-var contract-paused bool false)
;; Base Token URI for NFT metadata
(define-data-var base-token-uri (string-ascii 256) "https://api.example.com/ml-token/")

;; The gated non-fungible token
(define-non-fungible-token gated-ml-token uint)

;; Stores the ML score assigned to each user by the oracle
(define-map user-ml-scores principal uint)
;; Tracks whether a user has already minted their gated token
(define-map has-minted principal bool)
;; Tracks which tier a user minted
(define-map user-minted-tier principal uint)
;; Tracks asynchronous ML evaluation requests
(define-map evaluation-requests principal { requested-at: uint, is-pending: bool })
;; Blacklist for malicious users identified by ML
(define-map blacklist principal bool)

;; private functions 

;; @desc Helper to check if the caller is the authorized ML oracle
;; @param caller The principal to check
;; @returns bool
(define-private (is-oracle (caller principal))
    (is-eq caller (var-get ml-oracle))
)

;; @desc Helper to assert contract is not paused
(define-private (assert-not-paused)
    (begin
        (asserts! (not (var-get contract-paused)) err-paused)
        (ok true)
    )
)

;; @desc Helper to assert user is not blacklisted
(define-private (assert-not-blacklisted (user principal))
    (begin
        (asserts! (is-none (map-get? blacklist user)) err-blacklisted)
        (ok true)
    )
)

;; public functions 

;; --- Admin Functions ---

;; @desc Allows the contract owner to update the authorized ML oracle
(define-public (set-oracle (new-oracle principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set ml-oracle new-oracle))
    )
)

;; @desc Allows the contract owner to pause or unpause the contract
(define-public (set-paused (paused bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set contract-paused paused))
    )
)

;; @desc Allows the contract owner to update the evaluation fee
(define-public (set-evaluation-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set evaluation-fee new-fee))
    )
)

;; @desc Allows the contract owner to update the evaluation fee recipient
(define-public (set-fee-recipient (new-recipient principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set evaluation-fee-recipient new-recipient))
    )
)

;; @desc Allows the contract owner to update the base token URI
(define-public (set-base-token-uri (new-uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set base-token-uri new-uri))
    )
)

;; --- Oracle Functions ---

;; @desc Allows the oracle to proactively update a user's ML score
(define-public (update-user-score (user principal) (score uint))
    (begin
        (asserts! (is-oracle tx-sender) err-unauthorized-oracle)
        (try! (assert-not-paused))
        (ok (map-set user-ml-scores user score))
    )
)

;; @desc Allows the oracle or admin to blacklist a malicious user
(define-public (blacklist-user (user principal))
    (begin
        (asserts! (or (is-oracle tx-sender) (is-eq tx-sender contract-owner)) err-unauthorized-oracle)
        (ok (map-set blacklist user true))
    )
)

;; @desc Allows the oracle or admin to unblacklist a user
(define-public (remove-from-blacklist (user principal))
    (begin
        (asserts! (or (is-oracle tx-sender) (is-eq tx-sender contract-owner)) err-unauthorized-oracle)
        (ok (map-delete blacklist user))
    )
)

;; @desc Revokes a token if a user's ML score drops significantly or they act maliciously
(define-public (revoke-token (user principal) (token-id uint))
    (begin
        (asserts! (is-oracle tx-sender) err-unauthorized-oracle)
        (asserts! (is-eq (unwrap! (nft-get-owner? gated-ml-token token-id) err-not-token-owner) user) err-not-token-owner)
        (try! (nft-burn? gated-ml-token token-id user))
        (map-delete has-minted user)
        (map-delete user-minted-tier user)
        (ok true)
    )
)

;; --- User Minting Functions ---

;; @desc Allows a user to claim their gated token based on their ML score tier
;; @param tier The tier they are attempting to mint (1=Bronze, 2=Silver, 3=Gold)
(define-public (claim-tiered-token (tier uint))
    (let (
        (user-score (default-to u0 (map-get? user-ml-scores tx-sender)))
        (current-id (var-get nft-id-nonce))
        (required-score (if (is-eq tier u3) tier-3-threshold
                        (if (is-eq tier u2) tier-2-threshold
                        (if (is-eq tier u1) tier-1-threshold
                        u101)))) ;; u101 is unreachable out of 100
    )
        (try! (assert-not-paused))
        (try! (assert-not-blacklisted tx-sender))
        
        ;; Ensure the selected tier is valid
        (asserts! (<= tier u3) err-invalid-tier)
        (asserts! (> tier u0) err-invalid-tier)
        
        ;; Enforce the ML-powered token gate for the specific tier
        (asserts! (>= user-score required-score) err-score-too-low)
        ;; Ensure the user hasn't already minted
        (asserts! (is-none (map-get? has-minted tx-sender)) err-already-minted)
        
        ;; Mint the token securely
        (try! (nft-mint? gated-ml-token current-id tx-sender))
        
        ;; Update state to prevent double minting
        (map-set has-minted tx-sender true)
        (map-set user-minted-tier tx-sender tier)
        (var-set nft-id-nonce (+ current-id u1))
        
        ;; Emit a log for indexers
        (print { event: "mint", user: tx-sender, token-id: current-id, tier: tier })
        
        (ok current-id)
    )
)

;; --- ML Evaluation Request System ---

;; @desc Allows a user to request a fresh ML evaluation by paying a fee.
(define-public (request-ml-evaluation)
    (let (
        (existing-request (map-get? evaluation-requests tx-sender))
        (current-fee (var-get evaluation-fee))
    )
        (try! (assert-not-paused))
        (try! (assert-not-blacklisted tx-sender))
        
        ;; Check if there is already a pending request for this user to prevent spam
        (asserts! 
            (or 
                (is-none existing-request)
                (not (get is-pending (unwrap-panic existing-request)))
            ) 
            err-request-pending
        )
        
        ;; Transfer the evaluation fee from the user to the designated fee recipient
        (try! (stx-transfer? current-fee tx-sender (var-get evaluation-fee-recipient)))
        
        ;; Record the new evaluation request as pending
        (map-set evaluation-requests tx-sender {
            requested-at: block-height,
            is-pending: true
        })
        
        ;; Emit a log for the off-chain ML Oracle
        (print { event: "evaluation-requested", user: tx-sender })
        
        (ok true)
    )
)

;; @desc Allows the authorized ML oracle to fulfill a user's evaluation request.
(define-public (fulfill-ml-evaluation (user principal) (score uint))
    (let (
        (request (unwrap! (map-get? evaluation-requests user) err-no-request))
    )
        (try! (assert-not-paused))
        (asserts! (is-oracle tx-sender) err-unauthorized-oracle)
        (asserts! (get is-pending request) err-not-pending)
        
        ;; Update the user's ML score based on the off-chain evaluation
        (map-set user-ml-scores user score)
        
        ;; Mark the request as fulfilled
        (map-set evaluation-requests user {
            requested-at: (get requested-at request),
            is-pending: false
        })
        
        ;; Emit a log that evaluation is complete
        (print { event: "evaluation-fulfilled", user: user, new-score: score })
        
        (ok true)
    )
)

;; --- Read-Only Functions ---

(define-read-only (get-user-score (user principal))
    (ok (default-to u0 (map-get? user-ml-scores user)))
)

(define-read-only (has-user-minted (user principal))
    (ok (default-to false (map-get? has-minted user)))
)

(define-read-only (get-user-tier (user principal))
    (ok (map-get? user-minted-tier user))
)

(define-read-only (get-evaluation-request (user principal))
    (ok (map-get? evaluation-requests user))
)

(define-read-only (is-user-blacklisted (user principal))
    (ok (default-to false (map-get? blacklist user)))
)

(define-read-only (is-contract-paused)
    (ok (var-get contract-paused))
)

(define-read-only (get-evaluation-fee)
    (ok (var-get evaluation-fee))
)

(define-read-only (get-token-uri (token-id uint))
    (ok (some (var-get base-token-uri)))
)

(define-read-only (get-nft-owner (token-id uint))
    (ok (nft-get-owner? gated-ml-token token-id))
)

