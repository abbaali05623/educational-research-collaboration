;; Educational Research Collaboration - Project Coordinator Contract
;; Multi-institutional project coordination smart contract
;; Manages research projects, team members, milestones, and funding allocation
;; version: 1.0.0

;; ============================= CONSTANTS ===============================

;; Error codes
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))
(define-constant ERR-INVALID-STATUS (err u406))
(define-constant ERR-INVALID-ROLE (err u403))
(define-constant ERR-PROJECT-INACTIVE (err u425))
(define-constant ERR-INVALID-MILESTONE (err u407))
(define-constant ERR-MILESTONE-NOT-COMPLETE (err u422))

;; Role constants
(define-constant ROLE-PRINCIPAL-INVESTIGATOR u1)
(define-constant ROLE-CO-INVESTIGATOR u2)
(define-constant ROLE-RESEARCHER u3)
(define-constant ROLE-ADMIN u4)

;; Project status constants
(define-constant STATUS-DRAFT u0)
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-SUSPENDED u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-CANCELLED u4)

;; Minimum funding amount (1 STX)
(define-constant MIN-FUNDING-AMOUNT u1000000)
(define-constant MAX-INSTITUTIONS u20)
(define-constant MAX-MILESTONES u50)

;; ============================= DATA VARIABLES ===============================

;; Global counters
(define-data-var next-project-id uint u1)
(define-data-var next-milestone-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; ============================= DATA MAPS ===============================

;; Project details storage
(define-map projects
  uint
  {
    id: uint,
    title: (string-ascii 256),
    description: (string-ascii 1024),
    principal-investigator: principal,
    budget-required: uint,
    budget-allocated: uint,
    status: uint,
    institution-count: uint,
    milestone-count: uint,
    created-at: uint,
    updated-at: uint,
    completion-date: (optional uint)
  }
)

;; Project membership with roles
(define-map project-members
  { project-id: uint, member: principal }
  {
    project-id: uint,
    member: principal,
    role: uint,
    institution: (string-ascii 128),
    added-by: principal,
    added-at: uint,
    is-active: bool
  }
)

;; Project milestones
(define-map project-milestones
  { project-id: uint, milestone-id: uint }
  {
    project-id: uint,
    milestone-id: uint,
    title: (string-ascii 256),
    description: (string-ascii 512),
    allocated-amount: uint,
    target-date: uint,
    completion-date: (optional uint),
    is-complete: bool,
    verified-by: (optional principal),
    deliverable-hash: (optional (string-ascii 64))
  }
)

;; Project funding ledger
(define-map project-funding
  uint
  {
    project-id: uint,
    total-contributed: uint,
    total-disbursed: uint,
    available-balance: uint,
    last-disbursement: (optional uint)
  }
)

;; Funding contributions tracking
(define-map funding-contributions
  { project-id: uint, contributor: principal }
  {
    project-id: uint,
    contributor: principal,
    total-amount: uint,
    contribution-count: uint,
    first-contribution: uint,
    last-contribution: uint
  }
)

;; Project deliverables registry
(define-map project-deliverables
  { project-id: uint, deliverable-id: uint }
  {
    project-id: uint,
    deliverable-id: uint,
    title: (string-ascii 256),
    file-hash: (string-ascii 64),
    submitted-by: principal,
    submitted-at: uint,
    approved: bool,
    approved-by: (optional principal)
  }
)

;; ============================= HELPER FUNCTIONS ===============================

;; Check if caller is project PI
(define-private (is-principal-investigator (project-id uint) (caller principal))
  (match (map-get? projects project-id)
    project (is-eq (get principal-investigator project) caller)
    false
  )
)

;; Check if caller is project member with specific role
(define-private (is-project-member-with-role (project-id uint) (caller principal) (required-role uint))
  (match (map-get? project-members { project-id: project-id, member: caller })
    member-info (and (get is-active member-info) (is-eq (get role member-info) required-role))
    false
  )
)

;; Check if caller is authorized to modify project
(define-private (is-authorized (project-id uint) (caller principal))
  (or (is-principal-investigator project-id caller)
      (is-project-member-with-role project-id caller ROLE-CO-INVESTIGATOR)
      (is-project-member-with-role project-id caller ROLE-ADMIN))
)

;; Validate role value
(define-private (is-valid-role (role uint))
  (or (is-eq role ROLE-PRINCIPAL-INVESTIGATOR)
      (is-eq role ROLE-CO-INVESTIGATOR)
      (is-eq role ROLE-RESEARCHER)
      (is-eq role ROLE-ADMIN))
)

;; Validate project status
(define-private (is-valid-status (status uint))
  (or (is-eq status STATUS-DRAFT)
      (is-eq status STATUS-ACTIVE)
      (is-eq status STATUS-SUSPENDED)
      (is-eq status STATUS-COMPLETED)
      (is-eq status STATUS-CANCELLED))
)

;; ============================= PUBLIC FUNCTIONS ===============================

;; Create a new research project
(define-public (create-project 
  (title (string-ascii 256))
  (description (string-ascii 1024))
  (budget-required uint)
  (milestone-count uint)
)
  (let (
    (project-id (var-get next-project-id))
  )
    ;; Input validation
    (asserts! (> (len title) u0) (err u400))
    (asserts! (> (len description) u0) (err u400))
    (asserts! (>= budget-required MIN-FUNDING-AMOUNT) ERR-INVALID-AMOUNT)
    (asserts! (and (> milestone-count u0) (<= milestone-count MAX-MILESTONES)) (err u400))
    
    ;; Create project record
    (map-set projects project-id {
      id: project-id,
      title: title,
      description: description,
      principal-investigator: tx-sender,
      budget-required: budget-required,
      budget-allocated: u0,
      status: STATUS-DRAFT,
      institution-count: u1,
      milestone-count: milestone-count,
      created-at: block-height,
      updated-at: block-height,
      completion-date: none
    })
    
    ;; Add PI as first member
    (map-set project-members 
      { project-id: project-id, member: tx-sender }
      {
        project-id: project-id,
        member: tx-sender,
        role: ROLE-PRINCIPAL-INVESTIGATOR,
        institution: "Lead Institution",
        added-by: tx-sender,
        added-at: block-height,
        is-active: true
      }
    )
    
    ;; Initialize funding record
    (map-set project-funding project-id {
      project-id: project-id,
      total-contributed: u0,
      total-disbursed: u0,
      available-balance: u0,
      last-disbursement: none
    })
    
    ;; Increment counter
    (var-set next-project-id (+ project-id u1))
    
    ;; Log event
    (print {
      event: "project-created",
      project-id: project-id,
      pi: tx-sender,
      title: title,
      budget: budget-required
    })
    
    (ok project-id)
  )
)

;; Add member to project with specific role
(define-public (add-member 
  (project-id uint)
  (member principal)
  (role uint)
  (institution (string-ascii 128))
)
  (let (
    (project (unwrap! (map-get? projects project-id) ERR-NOT-FOUND))
  )
    ;; Authorization check
    (asserts! (is-authorized project-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Validate role
    (asserts! (is-valid-role role) ERR-INVALID-ROLE)
    
    ;; Check if member already exists
    (asserts! (is-none (map-get? project-members { project-id: project-id, member: member }))
              ERR-ALREADY-EXISTS)
    
    ;; Check institution limit
    (asserts! (< (get institution-count project) MAX-INSTITUTIONS) (err u429))
    
    ;; Add member
    (map-set project-members
      { project-id: project-id, member: member }
      {
        project-id: project-id,
        member: member,
        role: role,
        institution: institution,
        added-by: tx-sender,
        added-at: block-height,
        is-active: true
      }
    )
    
    ;; Update institution count
    (map-set projects project-id 
      (merge project { 
        institution-count: (+ (get institution-count project) u1),
        updated-at: block-height 
      })
    )
    
    ;; Log event
    (print {
      event: "member-added",
      project-id: project-id,
      member: member,
      role: role,
      institution: institution,
      added-by: tx-sender
    })
    
    (ok true)
  )
)

;; Create or update project milestone
(define-public (update-milestone
  (project-id uint)
  (milestone-index uint)
  (title (string-ascii 256))
  (description (string-ascii 512))
  (allocated-amount uint)
  (target-date uint)
)
  (let (
    (project (unwrap! (map-get? projects project-id) ERR-NOT-FOUND))
    (milestone-id (+ (* project-id u1000) milestone-index))
  )
    ;; Authorization check
    (asserts! (is-authorized project-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Validate milestone index
    (asserts! (< milestone-index (get milestone-count project)) ERR-INVALID-MILESTONE)
    
    ;; Validate amount
    (asserts! (> allocated-amount u0) ERR-INVALID-AMOUNT)
    
    ;; Create or update milestone
    (map-set project-milestones
      { project-id: project-id, milestone-id: milestone-id }
      {
        project-id: project-id,
        milestone-id: milestone-id,
        title: title,
        description: description,
        allocated-amount: allocated-amount,
        target-date: target-date,
        completion-date: none,
        is-complete: false,
        verified-by: none,
        deliverable-hash: none
      }
    )
    
    ;; Update project
    (map-set projects project-id 
      (merge project { updated-at: block-height })
    )
    
    ;; Log event
    (print {
      event: "milestone-updated",
      project-id: project-id,
      milestone-id: milestone-id,
      title: title,
      amount: allocated-amount
    })
    
    (ok milestone-id)
  )
)

;; Record project deliverable
(define-public (record-deliverable
  (project-id uint)
  (title (string-ascii 256))
  (file-hash (string-ascii 64))
)
  (let (
    (project (unwrap! (map-get? projects project-id) ERR-NOT-FOUND))
    (deliverable-id (+ (* project-id u10000) block-height))
  )
    ;; Authorization check - any active member can submit
    (asserts! (or (is-principal-investigator project-id tx-sender)
                  (is-some (map-get? project-members { project-id: project-id, member: tx-sender })))
              ERR-NOT-AUTHORIZED)
    
    ;; Project must be active
    (asserts! (is-eq (get status project) STATUS-ACTIVE) ERR-PROJECT-INACTIVE)
    
    ;; Record deliverable
    (map-set project-deliverables
      { project-id: project-id, deliverable-id: deliverable-id }
      {
        project-id: project-id,
        deliverable-id: deliverable-id,
        title: title,
        file-hash: file-hash,
        submitted-by: tx-sender,
        submitted-at: block-height,
        approved: false,
        approved-by: none
      }
    )
    
    ;; Update project
    (map-set projects project-id 
      (merge project { updated-at: block-height })
    )
    
    ;; Log event
    (print {
      event: "deliverable-recorded",
      project-id: project-id,
      deliverable-id: deliverable-id,
      title: title,
      submitted-by: tx-sender
    })
    
    (ok deliverable-id)
  )
)

;; Allocate funding to project
(define-public (allocate-funding (project-id uint) (amount uint))
  (let (
    (project (unwrap! (map-get? projects project-id) ERR-NOT-FOUND))
    (current-funding (default-to 
      { project-id: project-id, total-contributed: u0, total-disbursed: u0, 
        available-balance: u0, last-disbursement: none }
      (map-get? project-funding project-id)))
  )
    ;; Only contract owner or PI can allocate funding
    (asserts! (or (is-eq tx-sender (var-get contract-owner))
                  (is-principal-investigator project-id tx-sender))
              ERR-NOT-AUTHORIZED)
    
    ;; Validate amount
    (asserts! (>= amount MIN-FUNDING-AMOUNT) ERR-INVALID-AMOUNT)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update funding record
    (map-set project-funding project-id {
      project-id: project-id,
      total-contributed: (+ (get total-contributed current-funding) amount),
      total-disbursed: (get total-disbursed current-funding),
      available-balance: (+ (get available-balance current-funding) amount),
      last-disbursement: (get last-disbursement current-funding)
    })
    
    ;; Update project budget allocated
    (map-set projects project-id 
      (merge project { 
        budget-allocated: (+ (get budget-allocated project) amount),
        updated-at: block-height 
      })
    )
    
    ;; Track contribution
    (update-contribution-record project-id tx-sender amount)
    
    ;; Log event
    (print {
      event: "funding-allocated",
      project-id: project-id,
      contributor: tx-sender,
      amount: amount,
      total-allocated: (+ (get budget-allocated project) amount)
    })
    
    (ok amount)
  )
)

;; Complete milestone and trigger funding release
(define-public (complete-milestone
  (project-id uint)
  (milestone-index uint)
  (deliverable-hash (string-ascii 64))
)
  (let (
    (project (unwrap! (map-get? projects project-id) ERR-NOT-FOUND))
    (milestone-id (+ (* project-id u1000) milestone-index))
    (milestone (unwrap! (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id })
                       ERR-INVALID-MILESTONE))
    (funding (unwrap! (map-get? project-funding project-id) ERR-NOT-FOUND))
  )
    ;; Authorization check
    (asserts! (is-authorized project-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Project must be active
    (asserts! (is-eq (get status project) STATUS-ACTIVE) ERR-PROJECT-INACTIVE)
    
    ;; Milestone must not be complete
    (asserts! (not (get is-complete milestone)) ERR-ALREADY-EXISTS)
    
    ;; Validate sufficient funding
    (asserts! (>= (get available-balance funding) (get allocated-amount milestone))
              ERR-INSUFFICIENT-FUNDS)
    
    ;; Mark milestone complete
    (map-set project-milestones
      { project-id: project-id, milestone-id: milestone-id }
      (merge milestone {
        completion-date: (some block-height),
        is-complete: true,
        verified-by: (some tx-sender),
        deliverable-hash: (some deliverable-hash)
      })
    )
    
    ;; Disburse funds to PI
    (try! (as-contract 
      (stx-transfer? (get allocated-amount milestone) 
                    tx-sender 
                    (get principal-investigator project))))
    
    ;; Update funding record
    (map-set project-funding project-id 
      (merge funding {
        total-disbursed: (+ (get total-disbursed funding) (get allocated-amount milestone)),
        available-balance: (- (get available-balance funding) (get allocated-amount milestone)),
        last-disbursement: (some block-height)
      })
    )
    
    ;; Update project
    (map-set projects project-id 
      (merge project { updated-at: block-height })
    )
    
    ;; Log event
    (print {
      event: "milestone-completed",
      project-id: project-id,
      milestone-id: milestone-id,
      amount-disbursed: (get allocated-amount milestone),
      completed-by: tx-sender
    })
    
    (ok (get allocated-amount milestone))
  )
)

;; Close project (only PI)
(define-public (close-project (project-id uint) (final-status uint))
  (let (
    (project (unwrap! (map-get? projects project-id) ERR-NOT-FOUND))
    (funding (unwrap! (map-get? project-funding project-id) ERR-NOT-FOUND))
  )
    ;; Only PI can close project
    (asserts! (is-principal-investigator project-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Validate final status (completed or cancelled)
    (asserts! (or (is-eq final-status STATUS-COMPLETED)
                  (is-eq final-status STATUS-CANCELLED)) ERR-INVALID-STATUS)
    
    ;; Update project status
    (map-set projects project-id 
      (merge project {
        status: final-status,
        completion-date: (some block-height),
        updated-at: block-height
      })
    )
    
    ;; If cancelled, return remaining funds to PI
    (if (is-eq final-status STATUS-CANCELLED)
      (begin
        (if (> (get available-balance funding) u0)
          (try! (as-contract 
            (stx-transfer? (get available-balance funding)
                          tx-sender
                          (get principal-investigator project))))
          true)
        (map-set project-funding project-id 
          (merge funding {
            total-disbursed: (+ (get total-disbursed funding) (get available-balance funding)),
            available-balance: u0
          })
        )
      )
      true
    )
    
    ;; Log event
    (print {
      event: "project-closed",
      project-id: project-id,
      final-status: final-status,
      closed-by: tx-sender
    })
    
    (ok true)
  )
)

;; Update contribution record helper
(define-private (update-contribution-record (project-id uint) (contributor principal) (amount uint))
  (match (map-get? funding-contributions { project-id: project-id, contributor: contributor })
    existing
    (map-set funding-contributions
      { project-id: project-id, contributor: contributor }
      (merge existing {
        total-amount: (+ (get total-amount existing) amount),
        contribution-count: (+ (get contribution-count existing) u1),
        last-contribution: block-height
      })
    )
    ;; First contribution
    (map-set funding-contributions
      { project-id: project-id, contributor: contributor }
      {
        project-id: project-id,
        contributor: contributor,
        total-amount: amount,
        contribution-count: u1,
        first-contribution: block-height,
        last-contribution: block-height
      }
    )
  )
)

;; ============================= READ-ONLY FUNCTIONS ===============================

;; Get project details
(define-read-only (get-project (project-id uint))
  (map-get? projects project-id)
)

;; Get project member info
(define-read-only (get-project-member (project-id uint) (member principal))
  (map-get? project-members { project-id: project-id, member: member })
)

;; Get milestone details
(define-read-only (get-milestone (project-id uint) (milestone-index uint))
  (let (
    (milestone-id (+ (* project-id u1000) milestone-index))
  )
    (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id })
  )
)

;; Get project funding status
(define-read-only (get-project-funding-status (project-id uint))
  (map-get? project-funding project-id)
)

;; Get contribution details
(define-read-only (get-contribution (project-id uint) (contributor principal))
  (map-get? funding-contributions { project-id: project-id, contributor: contributor })
)

;; Get deliverable info
(define-read-only (get-deliverable (project-id uint) (deliverable-id uint))
  (map-get? project-deliverables { project-id: project-id, deliverable-id: deliverable-id })
)

;; Get next project ID
(define-read-only (get-next-project-id)
  (var-get next-project-id)
)

;; Get contract info
(define-read-only (get-contract-info)
  {
    version: "1.0.0",
    contract-owner: (var-get contract-owner),
    next-project-id: (var-get next-project-id),
    min-funding: MIN-FUNDING-AMOUNT,
    max-institutions: MAX-INSTITUTIONS,
    max-milestones: MAX-MILESTONES
  }
)

