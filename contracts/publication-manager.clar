;; Educational Research Collaboration - Publication Manager Contract
;; Intellectual property and publication management for research projects
;; Handles manuscript submissions, peer review, royalties, and impact tracking
;; version: 1.0.0

;; ============================= CONSTANTS ===============================

;; Error codes
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-PARAMS (err u400))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))
(define-constant ERR-INVALID-STATUS (err u406))
(define-constant ERR-PUBLICATION-LOCKED (err u423))
(define-constant ERR-INVALID-ROYALTY (err u424))
(define-constant ERR-NO-ROYALTIES (err u425))
(define-constant ERR-ATTRIBUTION-ERROR (err u426))

;; Publication status constants
(define-constant STATUS-DRAFT u1)
(define-constant STATUS-SUBMITTED u2)
(define-constant STATUS-UNDER-REVIEW u3)
(define-constant STATUS-ACCEPTED u4)
(define-constant STATUS-PUBLISHED u5)
(define-constant STATUS-REJECTED u6)
(define-constant STATUS-RETRACTED u7)

;; Author role constants
(define-constant ROLE-FIRST-AUTHOR u1)
(define-constant ROLE-CORRESPONDING-AUTHOR u2)
(define-constant ROLE-CO-AUTHOR u3)
(define-constant ROLE-CONTRIBUTING-AUTHOR u4)
(define-constant ROLE-SENIOR-AUTHOR u5)

;; IP ownership types
(define-constant OWNERSHIP-SOLE u1)
(define-constant OWNERSHIP-JOINT u2)
(define-constant OWNERSHIP-INSTITUTIONAL u3)
(define-constant OWNERSHIP-CONSORTIUM u4)

;; Royalty distribution types
(define-constant ROYALTY-EQUAL u1)
(define-constant ROYALTY-WEIGHTED u2)
(define-constant ROYALTY-HIERARCHICAL u3)
(define-constant ROYALTY-CUSTOM u4)

;; Maximum limits
(define-constant MAX-AUTHORS u50)
(define-constant MAX-PUBLICATIONS-PER-PROJECT u100)
(define-constant MIN-ROYALTY-AMOUNT u100000) ;; 0.1 STX

;; ============================= DATA VARIABLES ===============================

;; Global counters
(define-data-var next-publication-id uint u1)
(define-data-var next-review-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Statistics tracking
(define-data-var total-publications uint u0)
(define-data-var total-royalties-distributed uint u0)
(define-data-var total-citations uint u0)

;; ============================= DATA MAPS ===============================

;; Publication registry
(define-map publications
  uint
  {
    id: uint,
    project-id: uint,
    title: (string-ascii 512),
    abstract: (string-ascii 2048),
    doi: (optional (string-ascii 128)),
    status: uint,
    submission-date: uint,
    publication-date: (optional uint),
    publisher: (optional (string-ascii 256)),
    journal: (optional (string-ascii 256)),
    volume: (optional uint),
    issue: (optional uint),
    pages: (optional (string-ascii 32)),
    manuscript-hash: (string-ascii 64),
    total-royalties: uint,
    citation-count: uint,
    download-count: uint
  }
)

;; Author attribution and roles
(define-map publication-authors
  { publication-id: uint, author: principal }
  {
    publication-id: uint,
    author: principal,
    role: uint,
    affiliation: (string-ascii 256),
    contribution-percentage: uint,
    order-index: uint,
    added-by: principal,
    added-at: uint,
    verified: bool
  }
)

;; Intellectual property ownership
(define-map ip-ownership
  { publication-id: uint, owner: principal }
  {
    publication-id: uint,
    owner: principal,
    ownership-type: uint,
    ownership-percentage: uint,
    institution: (string-ascii 256),
    rights-granted: uint,
    license-terms: (string-ascii 512),
    established-at: uint
  }
)

;; Peer review tracking
(define-map peer-reviews
  uint
  {
    review-id: uint,
    publication-id: uint,
    reviewer: principal,
    review-score: uint,
    review-comments: (string-ascii 1024),
    recommendation: uint,
    submitted-at: uint,
    is-anonymous: bool,
    conflict-declared: bool
  }
)

;; Royalty distribution records
(define-map royalty-distributions
  { publication-id: uint, recipient: principal }
  {
    publication-id: uint,
    recipient: principal,
    total-earned: uint,
    total-claimed: uint,
    distribution-count: uint,
    last-distribution: (optional uint),
    percentage-share: uint
  }
)

;; Impact metrics tracking
(define-map impact-metrics
  uint
  {
    publication-id: uint,
    citation-count: uint,
    download-count: uint,
    social-mentions: uint,
    academic-score: uint,
    policy-citations: uint,
    media-coverage: uint,
    last-updated: uint
  }
)

;; Funding allocation for publications
(define-map publication-funding
  uint
  {
    publication-id: uint,
    total-allocated: uint,
    processing-fees: uint,
    open-access-fees: uint,
    marketing-budget: uint,
    remaining-balance: uint,
    last-disbursement: (optional uint)
  }
)

;; ============================= HELPER FUNCTIONS ===============================

;; Check if caller is publication author
(define-private (is-publication-author (publication-id uint) (caller principal))
  (is-some (map-get? publication-authors { publication-id: publication-id, author: caller }))
)

;; Check if caller is corresponding author
(define-private (is-corresponding-author (publication-id uint) (caller principal))
  (match (map-get? publication-authors { publication-id: publication-id, author: caller })
    author-info (is-eq (get role author-info) ROLE-CORRESPONDING-AUTHOR)
    false
  )
)

;; Check if caller can modify publication
(define-private (can-modify-publication (publication-id uint) (caller principal))
  (or (is-corresponding-author publication-id caller)
      (is-eq caller (var-get contract-owner))
      (is-publication-author publication-id caller))
)

;; Validate publication status
(define-private (is-valid-publication-status (status uint))
  (and (>= status STATUS-DRAFT) (<= status STATUS-RETRACTED))
)

;; Validate author role
(define-private (is-valid-author-role (role uint))
  (and (>= role ROLE-FIRST-AUTHOR) (<= role ROLE-SENIOR-AUTHOR))
)

;; Calculate royalty distribution amount
(define-private (calculate-royalty-share (total-amount uint) (percentage uint))
  (/ (* total-amount percentage) u100)
)

;; ============================= PUBLIC FUNCTIONS ===============================

;; Submit manuscript for publication
(define-public (submit-manuscript
  (project-id uint)
  (title (string-ascii 512))
  (abstract (string-ascii 2048))
  (manuscript-hash (string-ascii 64))
  (journal (string-ascii 256))
)
  (let (
    (publication-id (var-get next-publication-id))
  )
    ;; Input validation
    (asserts! (> (len title) u0) ERR-INVALID-PARAMS)
    (asserts! (> (len abstract) u0) ERR-INVALID-PARAMS)
    (asserts! (> (len manuscript-hash) u0) ERR-INVALID-PARAMS)
    
    ;; Create publication record
    (map-set publications publication-id {
      id: publication-id,
      project-id: project-id,
      title: title,
      abstract: abstract,
      doi: none,
      status: STATUS-DRAFT,
      submission-date: block-height,
      publication-date: none,
      publisher: none,
      journal: (some journal),
      volume: none,
      issue: none,
      pages: none,
      manuscript-hash: manuscript-hash,
      total-royalties: u0,
      citation-count: u0,
      download-count: u0
    })
    
    ;; Add submitter as corresponding author
    (map-set publication-authors
      { publication-id: publication-id, author: tx-sender }
      {
        publication-id: publication-id,
        author: tx-sender,
        role: ROLE-CORRESPONDING-AUTHOR,
        affiliation: "Lead Institution",
        contribution-percentage: u100,
        order-index: u0,
        added-by: tx-sender,
        added-at: block-height,
        verified: true
      }
    )
    
    ;; Initialize IP ownership
    (map-set ip-ownership
      { publication-id: publication-id, owner: tx-sender }
      {
        publication-id: publication-id,
        owner: tx-sender,
        ownership-type: OWNERSHIP-SOLE,
        ownership-percentage: u100,
        institution: "Lead Institution",
        rights-granted: u4,
        license-terms: "All rights reserved",
        established-at: block-height
      }
    )
    
    ;; Initialize funding record
    (map-set publication-funding publication-id {
      publication-id: publication-id,
      total-allocated: u0,
      processing-fees: u0,
      open-access-fees: u0,
      marketing-budget: u0,
      remaining-balance: u0,
      last-disbursement: none
    })
    
    ;; Increment counters
    (var-set next-publication-id (+ publication-id u1))
    (var-set total-publications (+ (var-get total-publications) u1))
    
    ;; Log event
    (print {
      event: "manuscript-submitted",
      publication-id: publication-id,
      project-id: project-id,
      title: title,
      submitted-by: tx-sender
    })
    
    (ok publication-id)
  )
)

;; Approve publication for release
(define-public (approve-publication
  (publication-id uint)
  (doi (string-ascii 128))
  (publisher (string-ascii 256))
  (volume uint)
  (issue uint)
  (pages (string-ascii 32))
)
  (let (
    (publication (unwrap! (map-get? publications publication-id) ERR-NOT-FOUND))
  )
    ;; Authorization check
    (asserts! (can-modify-publication publication-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Must be in submitted or under review status
    (asserts! (or (is-eq (get status publication) STATUS-SUBMITTED)
                  (is-eq (get status publication) STATUS-UNDER-REVIEW))
              ERR-INVALID-STATUS)
    
    ;; Update publication with approval details
    (map-set publications publication-id 
      (merge publication {
        doi: (some doi),
        status: STATUS-PUBLISHED,
        publication-date: (some block-height),
        publisher: (some publisher),
        volume: (some volume),
        issue: (some issue),
        pages: (some pages)
      })
    )
    
    ;; Initialize impact tracking
    (map-set impact-metrics publication-id {
      publication-id: publication-id,
      citation-count: u0,
      download-count: u0,
      social-mentions: u0,
      academic-score: u0,
      policy-citations: u0,
      media-coverage: u0,
      last-updated: block-height
    })
    
    ;; Log event
    (print {
      event: "publication-approved",
      publication-id: publication-id,
      doi: doi,
      approved-by: tx-sender
    })
    
    (ok true)
  )
)

;; Allocate funding for publication costs
(define-public (allocate-publication-funding
  (publication-id uint)
  (total-amount uint)
  (processing-fees uint)
  (open-access-fees uint)
  (marketing-budget uint)
)
  (let (
    (publication (unwrap! (map-get? publications publication-id) ERR-NOT-FOUND))
    (funding (default-to
      { publication-id: publication-id, total-allocated: u0, processing-fees: u0,
        open-access-fees: u0, marketing-budget: u0, remaining-balance: u0,
        last-disbursement: none }
      (map-get? publication-funding publication-id)))
  )
    ;; Authorization check
    (asserts! (can-modify-publication publication-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Validate amounts
    (asserts! (>= total-amount MIN-ROYALTY-AMOUNT) ERR-INVALID-PARAMS)
    (asserts! (is-eq total-amount (+ processing-fees (+ open-access-fees marketing-budget)))
              ERR-INVALID-PARAMS)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
    
    ;; Update funding record
    (map-set publication-funding publication-id {
      publication-id: publication-id,
      total-allocated: (+ (get total-allocated funding) total-amount),
      processing-fees: (+ (get processing-fees funding) processing-fees),
      open-access-fees: (+ (get open-access-fees funding) open-access-fees),
      marketing-budget: (+ (get marketing-budget funding) marketing-budget),
      remaining-balance: (+ (get remaining-balance funding) total-amount),
      last-disbursement: (get last-disbursement funding)
    })
    
    ;; Log event
    (print {
      event: "publication-funding-allocated",
      publication-id: publication-id,
      total-amount: total-amount,
      allocated-by: tx-sender
    })
    
    (ok total-amount)
  )
)

;; Distribute royalties to authors
(define-public (distribute-royalties
  (publication-id uint)
  (total-royalty-amount uint)
  (distribution-type uint)
)
  (let (
    (publication (unwrap! (map-get? publications publication-id) ERR-NOT-FOUND))
    (funding (unwrap! (map-get? publication-funding publication-id) ERR-NOT-FOUND))
  )
    ;; Authorization check
    (asserts! (can-modify-publication publication-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Must be published
    (asserts! (is-eq (get status publication) STATUS-PUBLISHED) ERR-INVALID-STATUS)
    
    ;; Validate royalty amount
    (asserts! (>= total-royalty-amount MIN-ROYALTY-AMOUNT) ERR-INVALID-ROYALTY)
    (asserts! (>= (get remaining-balance funding) total-royalty-amount) ERR-INSUFFICIENT-FUNDS)
    
    ;; Update funding balance
    (map-set publication-funding publication-id 
      (merge funding {
        remaining-balance: (- (get remaining-balance funding) total-royalty-amount),
        last-disbursement: (some block-height)
      })
    )
    
    ;; Update publication royalties
    (map-set publications publication-id 
      (merge publication {
        total-royalties: (+ (get total-royalties publication) total-royalty-amount)
      })
    )
    
    ;; Update global statistics
    (var-set total-royalties-distributed 
      (+ (var-get total-royalties-distributed) total-royalty-amount))
    
    ;; Log event
    (print {
      event: "royalties-distributed",
      publication-id: publication-id,
      total-amount: total-royalty-amount,
      distribution-type: distribution-type,
      distributed-by: tx-sender
    })
    
    (ok total-royalty-amount)
  )
)

;; Add author to publication
(define-public (add-author
  (publication-id uint)
  (author principal)
  (role uint)
  (affiliation (string-ascii 256))
  (contribution-percentage uint)
  (order-index uint)
)
  (let (
    (publication (unwrap! (map-get? publications publication-id) ERR-NOT-FOUND))
  )
    ;; Authorization check
    (asserts! (can-modify-publication publication-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Validate role and percentage
    (asserts! (is-valid-author-role role) ERR-INVALID-PARAMS)
    (asserts! (and (> contribution-percentage u0) (<= contribution-percentage u100)) ERR-INVALID-PARAMS)
    
    ;; Check if author already exists
    (asserts! (is-none (map-get? publication-authors { publication-id: publication-id, author: author }))
              ERR-ALREADY-EXISTS)
    
    ;; Publication must not be published yet
    (asserts! (< (get status publication) STATUS-PUBLISHED) ERR-PUBLICATION-LOCKED)
    
    ;; Add author
    (map-set publication-authors
      { publication-id: publication-id, author: author }
      {
        publication-id: publication-id,
        author: author,
        role: role,
        affiliation: affiliation,
        contribution-percentage: contribution-percentage,
        order-index: order-index,
        added-by: tx-sender,
        added-at: block-height,
        verified: false
      }
    )
    
    ;; Initialize royalty distribution record
    (map-set royalty-distributions
      { publication-id: publication-id, recipient: author }
      {
        publication-id: publication-id,
        recipient: author,
        total-earned: u0,
        total-claimed: u0,
        distribution-count: u0,
        last-distribution: none,
        percentage-share: contribution-percentage
      }
    )
    
    ;; Log event
    (print {
      event: "author-added",
      publication-id: publication-id,
      author: author,
      role: role,
      contribution: contribution-percentage,
      added-by: tx-sender
    })
    
    (ok true)
  )
)

;; Record impact metrics
(define-public (record-impact
  (publication-id uint)
  (new-citations uint)
  (new-downloads uint)
  (social-mentions uint)
  (academic-score uint)
)
  (let (
    (publication (unwrap! (map-get? publications publication-id) ERR-NOT-FOUND))
    (current-metrics (default-to
      { publication-id: publication-id, citation-count: u0, download-count: u0,
        social-mentions: u0, academic-score: u0, policy-citations: u0,
        media-coverage: u0, last-updated: u0 }
      (map-get? impact-metrics publication-id)))
  )
    ;; Any user can update impact metrics
    
    ;; Update impact metrics
    (map-set impact-metrics publication-id 
      (merge current-metrics {
        citation-count: (+ (get citation-count current-metrics) new-citations),
        download-count: (+ (get download-count current-metrics) new-downloads),
        social-mentions: (+ (get social-mentions current-metrics) social-mentions),
        academic-score: academic-score,
        last-updated: block-height
      })
    )
    
    ;; Update publication citation count
    (map-set publications publication-id 
      (merge publication {
        citation-count: (+ (get citation-count current-metrics) new-citations),
        download-count: (+ (get download-count current-metrics) new-downloads)
      })
    )
    
    ;; Update global statistics
    (var-set total-citations (+ (var-get total-citations) new-citations))
    
    ;; Log event
    (print {
      event: "impact-recorded",
      publication-id: publication-id,
      citations: new-citations,
      downloads: new-downloads,
      recorded-by: tx-sender
    })
    
    (ok true)
  )
)

;; Update publication status
(define-public (update-publication-status
  (publication-id uint)
  (new-status uint)
  (notes (string-ascii 512))
)
  (let (
    (publication (unwrap! (map-get? publications publication-id) ERR-NOT-FOUND))
  )
    ;; Authorization check
    (asserts! (can-modify-publication publication-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Validate status
    (asserts! (is-valid-publication-status new-status) ERR-INVALID-STATUS)
    
    ;; Update status
    (map-set publications publication-id 
      (merge publication { status: new-status })
    )
    
    ;; Log event
    (print {
      event: "publication-status-updated",
      publication-id: publication-id,
      old-status: (get status publication),
      new-status: new-status,
      updated-by: tx-sender,
      notes: notes
    })
    
    (ok true)
  )
)

;; ============================= READ-ONLY FUNCTIONS ===============================

;; Get publication details
(define-read-only (get-publication (publication-id uint))
  (map-get? publications publication-id)
)

;; Get author information
(define-read-only (get-publication-author (publication-id uint) (author principal))
  (map-get? publication-authors { publication-id: publication-id, author: author })
)

;; Get IP ownership details
(define-read-only (get-ip-ownership (publication-id uint) (owner principal))
  (map-get? ip-ownership { publication-id: publication-id, owner: owner })
)

;; Get royalty distribution info
(define-read-only (get-royalty-distribution (publication-id uint) (recipient principal))
  (map-get? royalty-distributions { publication-id: publication-id, recipient: recipient })
)

;; Get impact metrics
(define-read-only (get-impact-metrics (publication-id uint))
  (map-get? impact-metrics publication-id)
)

;; Get publication funding status
(define-read-only (get-publication-funding (publication-id uint))
  (map-get? publication-funding publication-id)
)

;; Get peer review details
(define-read-only (get-peer-review (review-id uint))
  (map-get? peer-reviews review-id)
)

;; Get next publication ID
(define-read-only (get-next-publication-id)
  (var-get next-publication-id)
)

;; Get contract statistics
(define-read-only (get-publication-stats)
  {
    total-publications: (var-get total-publications),
    total-royalties: (var-get total-royalties-distributed),
    total-citations: (var-get total-citations),
    next-publication-id: (var-get next-publication-id),
    contract-owner: (var-get contract-owner)
  }
)

