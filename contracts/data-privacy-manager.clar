;; Educational Research Collaboration - Data Privacy Manager Contract
;; Data sharing and privacy protection for research collaborations
;; Manages access control, compliance tracking, and data governance
;; version: 1.0.0

;; ============================= CONSTANTS ===============================

;; Error codes
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-PARAMS (err u400))
(define-constant ERR-ACCESS-DENIED (err u403))
(define-constant ERR-INVALID-SENSITIVITY (err u405))
(define-constant ERR-ASSET-LOCKED (err u423))
(define-constant ERR-COMPLIANCE-VIOLATION (err u451))
(define-constant ERR-INSUFFICIENT-CLEARANCE (err u452))
(define-constant ERR-BREACH-REPORTED (err u453))

;; Data sensitivity levels
(define-constant SENSITIVITY-PUBLIC u1)
(define-constant SENSITIVITY-INTERNAL u2)
(define-constant SENSITIVITY-CONFIDENTIAL u3)
(define-constant SENSITIVITY-RESTRICTED u4)
(define-constant SENSITIVITY-TOP-SECRET u5)

;; Access levels
(define-constant ACCESS-READ u1)
(define-constant ACCESS-WRITE u2)
(define-constant ACCESS-ADMIN u3)
(define-constant ACCESS-FULL u4)

;; Compliance status
(define-constant COMPLIANCE-COMPLIANT u1)
(define-constant COMPLIANCE-PENDING u2)
(define-constant COMPLIANCE-VIOLATED u3)
(define-constant COMPLIANCE-UNDER-REVIEW u4)

;; Maximum values
(define-constant MAX-ASSETS-PER-PROJECT u1000)
(define-constant MAX-ACCESS-GRANTS u100)
(define-constant MAX-URI-LENGTH u512)

;; ============================= DATA VARIABLES ===============================

;; Global counters
(define-data-var next-asset-id uint u1)
(define-data-var next-access-request-id uint u1)
(define-data-var contract-administrator principal tx-sender)

;; Compliance tracking
(define-data-var total-assets uint u0)
(define-data-var total-breaches uint u0)
(define-data-var last-audit-date uint u0)

;; ============================= DATA MAPS ===============================

;; Data asset registry
(define-map data-assets
  uint
  {
    id: uint,
    project-id: uint,
    uri: (string-ascii 512),
    title: (string-ascii 256),
    description: (string-ascii 1024),
    sensitivity-level: uint,
    owner: principal,
    custodian: principal,
    created-at: uint,
    updated-at: uint,
    access-count: uint,
    is-locked: bool,
    retention-period: uint,
    metadata-hash: (optional (string-ascii 64))
  }
)

;; Access control list
(define-map access-permissions
  { asset-id: uint, grantee: principal }
  {
    asset-id: uint,
    grantee: principal,
    access-level: uint,
    granted-by: principal,
    granted-at: uint,
    expires-at: (optional uint),
    is-active: bool,
    purpose: (string-ascii 256)
  }
)

;; Access requests tracking
(define-map access-requests
  uint
  {
    request-id: uint,
    asset-id: uint,
    requester: principal,
    requested-access-level: uint,
    justification: (string-ascii 512),
    requested-at: uint,
    reviewed-at: (optional uint),
    reviewed-by: (optional principal),
    status: uint,
    expires-at: (optional uint)
  }
)

;; Data access audit log
(define-map access-logs
  { asset-id: uint, accessor: principal, timestamp: uint }
  {
    asset-id: uint,
    accessor: principal,
    access-type: uint,
    timestamp: uint,
    ip-hash: (optional (string-ascii 64)),
    action-performed: (string-ascii 128),
    success: bool
  }
)

;; Compliance monitoring
(define-map compliance-status
  uint
  {
    asset-id: uint,
    status: uint,
    last-reviewed: uint,
    reviewed-by: principal,
    violations: uint,
    remediation-required: bool,
    notes: (string-ascii 512)
  }
)

;; Data breach incidents
(define-map breach-incidents
  uint
  {
    incident-id: uint,
    asset-id: uint,
    reported-by: principal,
    reported-at: uint,
    severity-level: uint,
    description: (string-ascii 1024),
    affected-records: uint,
    status: uint,
    resolved-at: (optional uint)
  }
)

;; Project data policies
(define-map project-data-policies
  uint
  {
    project-id: uint,
    retention-policy: uint,
    sharing-policy: uint,
    encryption-required: bool,
    audit-frequency: uint,
    compliance-officer: principal,
    last-updated: uint
  }
)

;; ============================= HELPER FUNCTIONS ===============================

;; Check if sensitivity level is valid
(define-private (is-valid-sensitivity (level uint))
  (and (>= level SENSITIVITY-PUBLIC) (<= level SENSITIVITY-TOP-SECRET))
)

;; Check if access level is valid
(define-private (is-valid-access-level (level uint))
  (and (>= level ACCESS-READ) (<= level ACCESS-FULL))
)

;; Check if user has sufficient clearance for asset
(define-private (has-sufficient-clearance (asset-id uint) (user principal) (required-level uint))
  (match (map-get? access-permissions { asset-id: asset-id, grantee: user })
    permission (and (get is-active permission)
                   (>= (get access-level permission) required-level)
                   (match (get expires-at permission)
                     expiry (> expiry block-height)
                     true))
    false
  )
)

;; Check if user is asset owner or custodian
(define-private (is-asset-controller (asset-id uint) (user principal))
  (match (map-get? data-assets asset-id)
    asset (or (is-eq (get owner asset) user)
              (is-eq (get custodian asset) user))
    false
  )
)

;; ============================= PUBLIC FUNCTIONS ===============================

;; Register a new data asset
(define-public (register-asset
  (project-id uint)
  (uri (string-ascii 512))
  (title (string-ascii 256))
  (description (string-ascii 1024))
  (sensitivity-level uint)
  (custodian principal)
  (retention-period uint)
)
  (let (
    (asset-id (var-get next-asset-id))
  )
    ;; Input validation
    (asserts! (> (len uri) u0) ERR-INVALID-PARAMS)
    (asserts! (> (len title) u0) ERR-INVALID-PARAMS)
    (asserts! (is-valid-sensitivity sensitivity-level) ERR-INVALID-SENSITIVITY)
    (asserts! (> retention-period u0) ERR-INVALID-PARAMS)
    
    ;; Register asset
    (map-set data-assets asset-id {
      id: asset-id,
      project-id: project-id,
      uri: uri,
      title: title,
      description: description,
      sensitivity-level: sensitivity-level,
      owner: tx-sender,
      custodian: custodian,
      created-at: block-height,
      updated-at: block-height,
      access-count: u0,
      is-locked: false,
      retention-period: retention-period,
      metadata-hash: none
    })
    
    ;; Grant full access to owner
    (map-set access-permissions
      { asset-id: asset-id, grantee: tx-sender }
      {
        asset-id: asset-id,
        grantee: tx-sender,
        access-level: ACCESS-FULL,
        granted-by: tx-sender,
        granted-at: block-height,
        expires-at: none,
        is-active: true,
        purpose: "Asset Owner"
      }
    )
    
    ;; Initialize compliance tracking
    (map-set compliance-status asset-id {
      asset-id: asset-id,
      status: COMPLIANCE-COMPLIANT,
      last-reviewed: block-height,
      reviewed-by: tx-sender,
      violations: u0,
      remediation-required: false,
      notes: "Initial registration"
    })
    
    ;; Update counters
    (var-set next-asset-id (+ asset-id u1))
    (var-set total-assets (+ (var-get total-assets) u1))
    
    ;; Log event
    (print {
      event: "asset-registered",
      asset-id: asset-id,
      project-id: project-id,
      owner: tx-sender,
      sensitivity: sensitivity-level,
      title: title
    })
    
    (ok asset-id)
  )
)

;; Grant access to a data asset
(define-public (grant-access
  (asset-id uint)
  (grantee principal)
  (access-level uint)
  (expires-at (optional uint))
  (purpose (string-ascii 256))
)
  (let (
    (asset (unwrap! (map-get? data-assets asset-id) ERR-NOT-FOUND))
  )
    ;; Authorization check
    (asserts! (is-asset-controller asset-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Validate access level
    (asserts! (is-valid-access-level access-level) ERR-INVALID-PARAMS)
    
    ;; Asset must not be locked
    (asserts! (not (get is-locked asset)) ERR-ASSET-LOCKED)
    
    ;; Grant access
    (map-set access-permissions
      { asset-id: asset-id, grantee: grantee }
      {
        asset-id: asset-id,
        grantee: grantee,
        access-level: access-level,
        granted-by: tx-sender,
        granted-at: block-height,
        expires-at: expires-at,
        is-active: true,
        purpose: purpose
      }
    )
    
    ;; Log event
    (print {
      event: "access-granted",
      asset-id: asset-id,
      grantee: grantee,
      access-level: access-level,
      granted-by: tx-sender,
      purpose: purpose
    })
    
    (ok true)
  )
)

;; Revoke access to a data asset
(define-public (revoke-access (asset-id uint) (grantee principal))
  (let (
    (asset (unwrap! (map-get? data-assets asset-id) ERR-NOT-FOUND))
    (permission (unwrap! (map-get? access-permissions { asset-id: asset-id, grantee: grantee })
                        ERR-NOT-FOUND))
  )
    ;; Authorization check
    (asserts! (is-asset-controller asset-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Revoke access
    (map-set access-permissions
      { asset-id: asset-id, grantee: grantee }
      (merge permission { is-active: false })
    )
    
    ;; Log event
    (print {
      event: "access-revoked",
      asset-id: asset-id,
      grantee: grantee,
      revoked-by: tx-sender
    })
    
    (ok true)
  )
)

;; Request access to a data asset
(define-public (request-access
  (asset-id uint)
  (requested-access-level uint)
  (justification (string-ascii 512))
  (expires-at (optional uint))
)
  (let (
    (asset (unwrap! (map-get? data-assets asset-id) ERR-NOT-FOUND))
    (request-id (var-get next-access-request-id))
  )
    ;; Validate access level
    (asserts! (is-valid-access-level requested-access-level) ERR-INVALID-PARAMS)
    
    ;; Validate justification
    (asserts! (> (len justification) u0) ERR-INVALID-PARAMS)
    
    ;; Create access request
    (map-set access-requests request-id {
      request-id: request-id,
      asset-id: asset-id,
      requester: tx-sender,
      requested-access-level: requested-access-level,
      justification: justification,
      requested-at: block-height,
      reviewed-at: none,
      reviewed-by: none,
      status: COMPLIANCE-PENDING,
      expires-at: expires-at
    })
    
    ;; Increment counter
    (var-set next-access-request-id (+ request-id u1))
    
    ;; Log event
    (print {
      event: "access-requested",
      request-id: request-id,
      asset-id: asset-id,
      requester: tx-sender,
      access-level: requested-access-level
    })
    
    (ok request-id)
  )
)

;; Log data access activity
(define-public (log-access
  (asset-id uint)
  (access-type uint)
  (action-performed (string-ascii 128))
  (ip-hash (optional (string-ascii 64)))
)
  (let (
    (asset (unwrap! (map-get? data-assets asset-id) ERR-NOT-FOUND))
  )
    ;; Check access permissions
    (asserts! (has-sufficient-clearance asset-id tx-sender ACCESS-READ) ERR-ACCESS-DENIED)
    
    ;; Log access
    (map-set access-logs
      { asset-id: asset-id, accessor: tx-sender, timestamp: block-height }
      {
        asset-id: asset-id,
        accessor: tx-sender,
        access-type: access-type,
        timestamp: block-height,
        ip-hash: ip-hash,
        action-performed: action-performed,
        success: true
      }
    )
    
    ;; Update asset access count
    (map-set data-assets asset-id 
      (merge asset { 
        access-count: (+ (get access-count asset) u1),
        updated-at: block-height
      })
    )
    
    ;; Log event
    (print {
      event: "data-accessed",
      asset-id: asset-id,
      accessor: tx-sender,
      action: action-performed
    })
    
    (ok true)
  )
)

;; Report data breach incident
(define-public (report-breach
  (asset-id uint)
  (severity-level uint)
  (description (string-ascii 1024))
  (affected-records uint)
)
  (let (
    (asset (unwrap! (map-get? data-assets asset-id) ERR-NOT-FOUND))
    (incident-id (+ (* asset-id u1000000) block-height))
  )
    ;; Validate severity
    (asserts! (and (> severity-level u0) (<= severity-level u5)) ERR-INVALID-PARAMS)
    
    ;; Any user can report a breach
    (asserts! (> (len description) u0) ERR-INVALID-PARAMS)
    
    ;; Record breach incident
    (map-set breach-incidents incident-id {
      incident-id: incident-id,
      asset-id: asset-id,
      reported-by: tx-sender,
      reported-at: block-height,
      severity-level: severity-level,
      description: description,
      affected-records: affected-records,
      status: COMPLIANCE-UNDER-REVIEW,
      resolved-at: none
    })
    
    ;; Lock asset if high severity
    (if (>= severity-level u4)
      (map-set data-assets asset-id (merge asset { is-locked: true }))
      true
    )
    
    ;; Update compliance status
    (map-set compliance-status asset-id {
      asset-id: asset-id,
      status: COMPLIANCE-VIOLATED,
      last-reviewed: block-height,
      reviewed-by: tx-sender,
      violations: (+ 
        (match (map-get? compliance-status asset-id)
          existing (get violations existing)
          u0) 
        u1),
      remediation-required: true,
      notes: "Data breach reported"
    })
    
    ;; Update global breach counter
    (var-set total-breaches (+ (var-get total-breaches) u1))
    
    ;; Log event
    (print {
      event: "breach-reported",
      incident-id: incident-id,
      asset-id: asset-id,
      severity: severity-level,
      reported-by: tx-sender
    })
    
    (ok incident-id)
  )
)

;; Update asset metadata and sensitivity
(define-public (update-asset-metadata
  (asset-id uint)
  (new-sensitivity uint)
  (metadata-hash (string-ascii 64))
  (notes (string-ascii 512))
)
  (let (
    (asset (unwrap! (map-get? data-assets asset-id) ERR-NOT-FOUND))
  )
    ;; Authorization check
    (asserts! (is-asset-controller asset-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Validate new sensitivity
    (asserts! (is-valid-sensitivity new-sensitivity) ERR-INVALID-SENSITIVITY)
    
    ;; Asset must not be locked
    (asserts! (not (get is-locked asset)) ERR-ASSET-LOCKED)
    
    ;; Update asset
    (map-set data-assets asset-id 
      (merge asset {
        sensitivity-level: new-sensitivity,
        metadata-hash: (some metadata-hash),
        updated-at: block-height
      })
    )
    
    ;; Update compliance if sensitivity changed
    (if (not (is-eq new-sensitivity (get sensitivity-level asset)))
      (map-set compliance-status asset-id {
        asset-id: asset-id,
        status: COMPLIANCE-PENDING,
        last-reviewed: block-height,
        reviewed-by: tx-sender,
        violations: (match (map-get? compliance-status asset-id)
          existing (get violations existing)
          u0),
        remediation-required: false,
        notes: notes
      })
      true
    )
    
    ;; Log event
    (print {
      event: "asset-metadata-updated",
      asset-id: asset-id,
      new-sensitivity: new-sensitivity,
      updated-by: tx-sender
    })
    
    (ok true)
  )
)

;; Set project data policy
(define-public (set-project-data-policy
  (project-id uint)
  (retention-policy uint)
  (sharing-policy uint)
  (encryption-required bool)
  (audit-frequency uint)
  (compliance-officer principal)
)
  (begin
    ;; Basic validation
    (asserts! (> retention-policy u0) ERR-INVALID-PARAMS)
    (asserts! (> audit-frequency u0) ERR-INVALID-PARAMS)
    
    ;; Set policy
    (map-set project-data-policies project-id {
      project-id: project-id,
      retention-policy: retention-policy,
      sharing-policy: sharing-policy,
      encryption-required: encryption-required,
      audit-frequency: audit-frequency,
      compliance-officer: compliance-officer,
      last-updated: block-height
    })
    
    ;; Log event
    (print {
      event: "data-policy-set",
      project-id: project-id,
      set-by: tx-sender,
      compliance-officer: compliance-officer
    })
    
    (ok true)
  )
)

;; ============================= READ-ONLY FUNCTIONS ===============================

;; Get data asset details
(define-read-only (get-data-asset (asset-id uint))
  (map-get? data-assets asset-id)
)

;; Get access permission details
(define-read-only (get-access-permission (asset-id uint) (grantee principal))
  (map-get? access-permissions { asset-id: asset-id, grantee: grantee })
)

;; Get access request details
(define-read-only (get-access-request (request-id uint))
  (map-get? access-requests request-id)
)

;; Get compliance status
(define-read-only (get-compliance-status (asset-id uint))
  (map-get? compliance-status asset-id)
)

;; Get breach incident details
(define-read-only (get-breach-incident (incident-id uint))
  (map-get? breach-incidents incident-id)
)

;; Get project data policy
(define-read-only (get-project-data-policy (project-id uint))
  (map-get? project-data-policies project-id)
)

;; Check if user has access to asset
(define-read-only (check-access (asset-id uint) (user principal) (required-level uint))
  (has-sufficient-clearance asset-id user required-level)
)

;; Get asset access log
(define-read-only (get-access-log (asset-id uint) (accessor principal) (timestamp uint))
  (map-get? access-logs { asset-id: asset-id, accessor: accessor, timestamp: timestamp })
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-assets: (var-get total-assets),
    total-breaches: (var-get total-breaches),
    last-audit: (var-get last-audit-date),
    next-asset-id: (var-get next-asset-id),
    administrator: (var-get contract-administrator)
  }
)

;; Get next asset ID
(define-read-only (get-next-asset-id)
  (var-get next-asset-id)
)

