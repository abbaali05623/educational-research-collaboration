;; Educational Research Collaboration Contract
;; A smart contract for managing research project funding and collaboration
;; version: 1.0.0
;; summary: Enables milestone-based funding for educational research projects
;; description: Researchers can register projects, add collaborators, receive funding,
;;              and release funds based on milestone completion

;; ============================= CONSTANTS ===============================

;; Error codes
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))
(define-constant ERR-INVALID-STATUS (err u406))
(define-constant ERR-MILESTONE-INCOMPLETE (err u422))
(define-constant ERR-INVALID-MILESTONE (err u407))

;; Project status constants
(define-constant STATUS-ACTIVE "active")
(define-constant STATUS-COMPLETED "completed")
(define-constant STATUS-CANCELLED "cancelled")
(define-constant STATUS-PAUSED "paused")

;; Minimum funding amount (1 STX)
(define-constant MIN-FUNDING-AMOUNT u1000000)

;; ============================= DATA VARIABLES ===============================

;; Global project counter for unique IDs
(define-data-var next-project-id uint u1)

;; Contract owner (for administrative functions)
(define-data-var contract-owner principal tx-sender)

;; ============================= DATA MAPS ===============================

;; Project storage: maps project ID to project details
(define-map projects
  uint
  {
    id: uint,
    title: (string-ascii 256),
    owner: principal,
    budget: uint,
    status: (string-ascii 32),
    milestone-count: uint,
    total-funded: uint,
    total-disbursed: uint,
    created-at: uint
  }
)

;; Milestone storage: maps (project-id, milestone-index) to milestone details
(define-map milestones
  { project-id: uint, index: uint }
  {
    project-id: uint,
    index: uint,
    description: (string-ascii 512),
    amount: uint,
    is-complete: bool,
    completed-by: (optional principal),
    completed-at: (optional uint)
  }
)

;; Project collaborators: maps (project-id, collaborator) to permissions
(define-map collaborators
  { project-id: uint, collaborator: principal }
  {
    project-id: uint,
    collaborator: principal,
    added-by: principal,
    added-at: uint
  }
)

;; Funding contributions: maps (project-id, contributor) to contribution details
(define-map contributions
  { project-id: uint, contributor: principal }
  {
    project-id: uint,
    contributor: principal,
    total-amount: uint,
    contribution-count: uint,
    first-contribution-at: uint,
    last-contribution-at: uint
  }
)

;; Project funding escrow: maps project-id to available funds
(define-map project-escrow
  uint
  { available-funds: uint }
)

;; ============================= HELPER FUNCTIONS ===============================

;; Check if caller is project owner
(define-private (is-project-owner (project-id uint) (caller principal))
  (match (map-get? projects project-id)
    project (is-eq (get owner project) caller)
    false
  )
)

;; Check if caller is project collaborator
(define-private (is-project-collaborator (project-id uint) (caller principal))
  (is-some (map-get? collaborators { project-id: project-id, collaborator: caller }))
)

;; Check if caller can modify project (owner or collaborator)
(define-private (can-modify-project (project-id uint) (caller principal))
  (or (is-project-owner project-id caller)
      (is-project-collaborator project-id caller))
)

;; Calculate milestone funding amount based on project budget and milestone count
(define-private (calculate-milestone-amount (budget uint) (milestone-count uint))
  (/ budget milestone-count)
)

;; Validate project status
(define-private (is-valid-status (status (string-ascii 32)))
  (or (is-eq status STATUS-ACTIVE)
      (is-eq status STATUS-COMPLETED)
      (is-eq status STATUS-CANCELLED)
      (is-eq status STATUS-PAUSED))
)

;; ============================= PUBLIC FUNCTIONS ===============================

;; Register a new research project
(define-public (register-project (title (string-ascii 256)) (budget uint) (milestone-count uint))
  (let (
    (project-id (var-get next-project-id))
    (milestone-amount (calculate-milestone-amount budget milestone-count))
  )
    ;; Validate inputs
    (asserts! (> (len title) u0) (err u400))
    (asserts! (>= budget MIN-FUNDING-AMOUNT) ERR-INVALID-AMOUNT)
    (asserts! (> milestone-count u0) (err u400))
    (asserts! (<= milestone-count u50) (err u400)) ;; Max 50 milestones
    
    ;; Create project record
    (map-set projects project-id {
      id: project-id,
      title: title,
      owner: tx-sender,
      budget: budget,
      status: STATUS-ACTIVE,
      milestone-count: milestone-count,
      total-funded: u0,
      total-disbursed: u0,
      created-at: block-height
    })
    
    ;; Initialize project escrow
    (map-set project-escrow project-id { available-funds: u0 })
    
    ;; Create milestone placeholders
    (create-milestones project-id milestone-count milestone-amount)
    
    ;; Increment counter
    (var-set next-project-id (+ project-id u1))
    
    ;; Emit event
    (print {
      event: "project-registered",
      project-id: project-id,
      owner: tx-sender,
      title: title,
      budget: budget,
      milestone-count: milestone-count
    })
    
    (ok project-id)
  )
)

;; Helper function to create milestone records (iterative approach)
(define-private (create-milestones (project-id uint) (milestone-count uint) (amount uint))
  (begin
    (map-set milestones { project-id: project-id, index: u0 } 
      { project-id: project-id, index: u0, description: "Milestone placeholder - to be updated", 
        amount: amount, is-complete: false, completed-by: none, completed-at: none })
    (if (> milestone-count u1)
      (map-set milestones { project-id: project-id, index: u1 } 
        { project-id: project-id, index: u1, description: "Milestone placeholder - to be updated", 
          amount: amount, is-complete: false, completed-by: none, completed-at: none })
      true)
    (if (> milestone-count u2)
      (map-set milestones { project-id: project-id, index: u2 } 
        { project-id: project-id, index: u2, description: "Milestone placeholder - to be updated", 
          amount: amount, is-complete: false, completed-by: none, completed-at: none })
      true)
    (if (> milestone-count u3)
      (map-set milestones { project-id: project-id, index: u3 } 
        { project-id: project-id, index: u3, description: "Milestone placeholder - to be updated", 
          amount: amount, is-complete: false, completed-by: none, completed-at: none })
      true)
    (if (> milestone-count u4)
      (map-set milestones { project-id: project-id, index: u4 } 
        { project-id: project-id, index: u4, description: "Milestone placeholder - to be updated", 
          amount: amount, is-complete: false, completed-by: none, completed-at: none })
      true)
    true
  )
)

;; Add a collaborator to a project
(define-public (add-collaborator (project-id uint) (collaborator principal))
  (let (
    (project (unwrap! (map-get? projects project-id) ERR-NOT-FOUND))
  )
    ;; Only project owner can add collaborators
    (asserts! (is-project-owner project-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Check if collaborator already exists
    (asserts! (is-none (map-get? collaborators { project-id: project-id, collaborator: collaborator })) 
              ERR-ALREADY-EXISTS)
    
    ;; Add collaborator
    (map-set collaborators 
      { project-id: project-id, collaborator: collaborator }
      {
        project-id: project-id,
        collaborator: collaborator,
        added-by: tx-sender,
        added-at: block-height
      }
    )
    
    ;; Emit event
    (print {
      event: "collaborator-added",
      project-id: project-id,
      collaborator: collaborator,
      added-by: tx-sender
    })
    
    (ok true)
  )
)

;; Fund a project with STX
(define-public (fund-project (project-id uint))
  (let (
    (project (unwrap! (map-get? projects project-id) ERR-NOT-FOUND))
    (funding-amount (stx-get-balance tx-sender))
    (current-escrow (default-to { available-funds: u0 } 
                    (map-get? project-escrow project-id)))
    (current-contribution (map-get? contributions 
                          { project-id: project-id, contributor: tx-sender }))
  )
    ;; Validate project is active
    (asserts! (is-eq (get status project) STATUS-ACTIVE) ERR-INVALID-STATUS)
    
    ;; Validate funding amount
    (asserts! (>= funding-amount MIN-FUNDING-AMOUNT) ERR-INVALID-AMOUNT)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? funding-amount tx-sender (as-contract tx-sender)))
    
    ;; Update project escrow
    (map-set project-escrow project-id {
      available-funds: (+ (get available-funds current-escrow) funding-amount)
    })
    
    ;; Update project total funded
    (map-set projects project-id 
      (merge project { total-funded: (+ (get total-funded project) funding-amount) })
    )
    
    ;; Update contribution record
    (match current-contribution
      existing-contribution
      (map-set contributions
        { project-id: project-id, contributor: tx-sender }
        {
          project-id: project-id,
          contributor: tx-sender,
          total-amount: (+ (get total-amount existing-contribution) funding-amount),
          contribution-count: (+ (get contribution-count existing-contribution) u1),
          first-contribution-at: (get first-contribution-at existing-contribution),
          last-contribution-at: block-height
        }
      )
      ;; First contribution
      (map-set contributions
        { project-id: project-id, contributor: tx-sender }
        {
          project-id: project-id,
          contributor: tx-sender,
          total-amount: funding-amount,
          contribution-count: u1,
          first-contribution-at: block-height,
          last-contribution-at: block-height
        }
      )
    )
    
    ;; Emit event
    (print {
      event: "project-funded",
      project-id: project-id,
      contributor: tx-sender,
      amount: funding-amount,
      total-project-funding: (+ (get total-funded project) funding-amount)
    })
    
    (ok funding-amount)
  )
)

;; Mark a milestone as complete (only owner or collaborator)
(define-public (mark-milestone-complete (project-id uint) (index uint))
  (let (
    (project (unwrap! (map-get? projects project-id) ERR-NOT-FOUND))
    (milestone (unwrap! (map-get? milestones { project-id: project-id, index: index }) 
                       ERR-INVALID-MILESTONE))
  )
    ;; Validate permissions
    (asserts! (can-modify-project project-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Validate project is active
    (asserts! (is-eq (get status project) STATUS-ACTIVE) ERR-INVALID-STATUS)
    
    ;; Validate milestone not already complete
    (asserts! (not (get is-complete milestone)) ERR-ALREADY-EXISTS)
    
    ;; Mark milestone complete
    (map-set milestones
      { project-id: project-id, index: index }
      (merge milestone {
        is-complete: true,
        completed-by: (some tx-sender),
        completed-at: (some block-height)
      })
    )
    
    ;; Emit event
    (print {
      event: "milestone-completed",
      project-id: project-id,
      milestone-index: index,
      completed-by: tx-sender
    })
    
    (ok true)
  )
)

;; Disburse funds for a completed milestone
(define-public (disburse-funds (project-id uint) (index uint))
  (let (
    (project (unwrap! (map-get? projects project-id) ERR-NOT-FOUND))
    (milestone (unwrap! (map-get? milestones { project-id: project-id, index: index }) 
                       ERR-INVALID-MILESTONE))
    (current-escrow (unwrap! (map-get? project-escrow project-id) ERR-NOT-FOUND))
    (disbursement-amount (get amount milestone))
  )
    ;; Validate permissions (only owner can disburse)
    (asserts! (is-project-owner project-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Validate milestone is complete
    (asserts! (get is-complete milestone) ERR-MILESTONE-INCOMPLETE)
    
    ;; Validate sufficient funds
    (asserts! (>= (get available-funds current-escrow) disbursement-amount) 
              ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer funds to project owner
    (try! (as-contract (stx-transfer? disbursement-amount tx-sender (get owner project))))
    
    ;; Update escrow
    (map-set project-escrow project-id {
      available-funds: (- (get available-funds current-escrow) disbursement-amount)
    })
    
    ;; Update project total disbursed
    (map-set projects project-id 
      (merge project { total-disbursed: (+ (get total-disbursed project) disbursement-amount) })
    )
    
    ;; Emit event
    (print {
      event: "funds-disbursed",
      project-id: project-id,
      milestone-index: index,
      amount: disbursement-amount,
      recipient: (get owner project)
    })
    
    (ok disbursement-amount)
  )
)

;; Update project status (owner only)
(define-public (update-project-status (project-id uint) (new-status (string-ascii 32)))
  (let (
    (project (unwrap! (map-get? projects project-id) ERR-NOT-FOUND))
  )
    ;; Validate permissions
    (asserts! (is-project-owner project-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Validate new status
    (asserts! (is-valid-status new-status) ERR-INVALID-STATUS)
    
    ;; Update project status
    (map-set projects project-id (merge project { status: new-status }))
    
    ;; Emit event
    (print {
      event: "project-status-updated",
      project-id: project-id,
      old-status: (get status project),
      new-status: new-status
    })
    
    (ok true)
  )
)

;; ============================= READ-ONLY FUNCTIONS ===============================

;; Get project details
(define-read-only (get-project (project-id uint))
  (map-get? projects project-id)
)

;; Get milestone details
(define-read-only (get-milestone (project-id uint) (index uint))
  (map-get? milestones { project-id: project-id, index: index })
)

;; Get project funding information
(define-read-only (get-project-funding (project-id uint))
  (let (
    (project (map-get? projects project-id))
    (escrow (map-get? project-escrow project-id))
  )
    (match project
      p (some {
        project-id: project-id,
        total-funded: (get total-funded p),
        total-disbursed: (get total-disbursed p),
        available-funds: (match escrow
          e (get available-funds e)
          u0),
        budget: (get budget p)
      })
      none
    )
  )
)

;; Check if user is collaborator
(define-read-only (get-collaborator (project-id uint) (collaborator principal))
  (map-get? collaborators { project-id: project-id, collaborator: collaborator })
)

;; Get contribution details
(define-read-only (get-contribution (project-id uint) (contributor principal))
  (map-get? contributions { project-id: project-id, contributor: contributor })
)

;; Get next project ID
(define-read-only (get-next-project-id)
  (var-get next-project-id)
)

;; Get contract info
(define-read-only (get-contract-info)
  {
    version: "1.0.0",
    owner: (var-get contract-owner),
    next-project-id: (var-get next-project-id),
    min-funding-amount: MIN-FUNDING-AMOUNT
  }
)
