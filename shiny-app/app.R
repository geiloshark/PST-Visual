# ─────────────────────────────────────────────────────────────────────────────
# pstom Shiny Interface
# Run with: shiny::runApp("path/to/shiny-app")
# ─────────────────────────────────────────────────────────────────────────────

# Dependency check -----------------------------------------------------------
missing_pkgs <- character(0)
for (pkg in c("shiny", "ggplot2", "pstom")) {
  if (!requireNamespace(pkg, quietly = TRUE)) missing_pkgs <- c(missing_pkgs, pkg)
}
if (length(missing_pkgs)) {
  cat("Missing packages:", paste(missing_pkgs, collapse = ", "), "\n")
  cat("Install with:\n")
  if ("pstom" %in% missing_pkgs) {
    cat('  remotes::install_github("geiloshark/PST-Visual", subdir = "pstom")\n')
    missing_pkgs <- setdiff(missing_pkgs, "pstom")
  }
  if (length(missing_pkgs)) {
    cat('  install.packages(c("', paste(missing_pkgs, collapse = '", "'), '"))\n', sep = "")
  }
  stop("Please install the packages above and restart the app.")
}

library(shiny)
library(ggplot2)
library(pstom)

# ── Helpers ───────────────────────────────────────────────────────────────────
# Build a distribution from two par inputs + density string.
# When density == "unspecified", Par 1 is treated as a fixed value and Par 2
# is ignored. Returns NULL if Par 1 is blank (nothing to load).
.build_dist <- function(p1, p2, dens, name = "") {
  p1 <- suppressWarnings(as.numeric(p1))
  p2 <- suppressWarnings(as.numeric(p2))
  if (is.na(p1)) return(NULL)          # Par 1 always required
  if (dens == "unspecified") {
    # Fixed value: store as a single-element numeric distribution
    return(distribution(value = p1, density = "unspecified", name = name))
  }
  pars_vec <- c(p1, if (is.na(p2)) NA_real_ else p2)
  distribution(pars = pars_vec, density = dens, name = name)
}

# Format an integer ages vector as a compact R expression string.
.ages_to_expr <- function(ages) {
  ages <- sort(unique(as.integer(ages)))
  # Detect simple 0:N contiguous sequence
  if (length(ages) >= 2 && all(diff(ages) == 1L) && ages[1] == 0L) {
    return(paste0("0:", ages[length(ages)]))
  }
  paste0("c(", paste(ages, collapse = ", "), ")")
}

# Populate Basic tab inputs from a loaded om object.
.populate_basic_from_om <- function(session, obj) {

  # Ages — format as compact R expression
  if (length(obj@ages) > 0 && !all(is.na(obj@ages))) {
    updateTextInput(session, "om_ages", value = .ages_to_expr(obj@ages))
  }

  # Samples
  if (!is.na(obj@samples) && obj@samples > 0L) {
    updateNumericInput(session, "om_samples", value = as.integer(obj@samples))
  }

  # Time — stored as 0:(n-1) vector; expose as number of years
  if (length(obj@time) > 0 && !all(is.na(obj@time))) {
    updateNumericInput(session, "om_time", value = length(obj@time))
  }

  # Shape — use mean of estimated values if present
  if (length(obj@shape) > 0 && !all(is.na(obj@shape))) {
    updateNumericInput(session, "om_shape",
                       value = round(mean(obj@shape, na.rm = TRUE), 6))
  } else {
    updateNumericInput(session, "om_shape", value = NA)
  }
}

# Populate Pars tab inputs from a loaded om object.
# Called immediately when an RDS is uploaded so the user sees the values.
# Works even while the Upload radio is active (inputs are in the DOM, just hidden).
.populate_pars_from_om <- function(session, obj) {
  par_map <- list(
    s = "par_s", l = "par_l", b = "par_b", m = "par_m",
    o = "par_o", v = "par_v", K = "par_K"
  )
  for (par_name in names(par_map)) {
    prefix <- par_map[[par_name]]
    dist   <- obj@pars[[par_name]]
    if (!is(dist, "distribution")) next   # slot is NA / not a distribution — skip

    dens <- dist@density

    if (dens == "unspecified") {
      # No parametric pars — use mean of stored values as the fixed value
      vals <- as.numeric(dist)           # accesses the .Data slot
      p1   <- if (length(vals) > 0 && !all(is.na(vals))) mean(vals, na.rm = TRUE) else NA_real_
      p2   <- NA_real_
    } else {
      p1 <- if (length(dist@pars) >= 1) dist@pars[1] else NA_real_
      p2 <- if (length(dist@pars) >= 2) dist@pars[2] else NA_real_
    }

    updateNumericInput(session, paste0(prefix, "_p1"), value = p1)
    updateNumericInput(session, paste0(prefix, "_p2"), value = p2)
    updateSelectInput( session, paste0(prefix, "_dens"), selected = dens)
  }
}

# ── CSS helpers ───────────────────────────────────────────────────────────────
app_css <- "
  body { font-family: 'Segoe UI', Arial, sans-serif; background: #f8f9fa; }
  h1.app-title {
    font-size: 20px; font-weight: 700; margin: 0;
    padding: 14px 20px 10px;
    border-bottom: 1px solid #e5e7eb;
  }
  .tab-content { padding: 20px; }
  .well { background: #fff; border: 1px solid #e5e7eb; border-radius: 8px; box-shadow: none; }
  .btn-primary { background: #1d4ed8; border-color: #1d4ed8; }
  .btn-primary:hover { background: #1e40af; border-color: #1e40af; }
  .btn-success { background: #16a34a; border-color: #16a34a; }
  .log-box {
    background: #111827; color: #d1fae5; font-family: monospace;
    font-size: 12px; padding: 12px; border-radius: 6px;
    max-height: 300px; overflow-y: auto; white-space: pre-wrap;
  }
  .status-ok  { color: #16a34a; font-weight: 600; }
  .status-err { color: #dc2626; font-weight: 600; }
  .section-label { font-weight: 600; font-size: 13px; margin-bottom: 2px; color: #374151; }
  .sub-label  { font-weight: 600; font-size: 11px; margin-bottom: 1px; color: #6b7280; text-transform: uppercase; letter-spacing: .04em; }
  .helper-text { font-size: 11px; color: #6b7280; margin-top: 1px; margin-bottom: 6px; }
  .par-block { background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 6px; padding: 10px 10px 4px; margin-bottom: 8px; }
  .section-divider { border-top: 1px solid #e5e7eb; margin: 12px 0 10px; }
  .btn[disabled] { opacity: 0.45; cursor: not-allowed; pointer-events: none; }
  /* tighten inner tab nav */
  .inner-tabs .nav-tabs { margin-bottom: 10px; }
  .inner-tabs .nav-tabs > li > a { padding: 5px 10px; font-size: 12px; }
"

# ── Density choices ───────────────────────────────────────────────────────────
density_choices <- c(
  "unspecified"  = "unspecified",
  "normal"       = "normal",
  "lognormal"    = "lognormal",
  "beta"         = "beta",
  "uniform"      = "uniform",
  "gamma"        = "gamma",
  "logitnormal"  = "logitnormal",
  "zt-normal"    = "zt-normal"
)

# Helper: one par row (par1/par2/density) inside a labelled block.
# Par 2 is hidden when density == "unspecified" (Par 1 treated as fixed value).
par_block_ui <- function(prefix, label, hint = "", default_dens = "unspecified") {
  dens_id <- paste0(prefix, "_dens")
  p2_cond <- paste0("input['", dens_id, "'] !== 'unspecified'")
  div(class = "par-block",
    div(class = "sub-label", label),
    if (nchar(hint) > 0) div(class = "helper-text", hint),
    fluidRow(
      column(4, numericInput(paste0(prefix, "_p1"), "Par 1 (value)", value = NA, step = 0.01)),
      column(4,
        conditionalPanel(p2_cond,
          numericInput(paste0(prefix, "_p2"), "Par 2", value = NA, step = 0.01)
        ),
        conditionalPanel(paste0("!(", p2_cond, ")"),
          div(style = "padding-top:25px;",
            span(class = "helper-text", "Fixed value — Par 2 not used")
          )
        )
      ),
      column(4, selectInput(dens_id, "Density",
                            choices = density_choices, selected = default_dens))
    )
  )
}

# ── UI ────────────────────────────────────────────────────────────────────────
ui <- fluidPage(
  title = "pstom Interface",
  tags$head(tags$style(HTML(app_css))),
  h1("pstom R Interface", class = "app-title"),

  tabsetPanel(id = "main_tabs",

    # ── Tab 1: om ─────────────────────────────────────────────────────────────
    tabPanel("1 · om",
      fluidRow(
        column(4,
          wellPanel(
            h4("om object"),

            # Source toggle
            radioButtons("om_source", label = NULL,
              choices = list(
                "Build from inputs" = "build",
                "Upload existing RDS" = "upload"
              ),
              selected = "build"
            ),

            # ── Upload path ──────────────────────────────────────────────────
            conditionalPanel("input.om_source == 'upload'",
              fileInput("om_upload", label = NULL,
                        accept = c(".rds", ".RDS"),
                        buttonLabel = "Browse…",
                        placeholder = "Select om RDS file"),
              p(class = "helper-text", "File must contain a saved ", code("om"), " S4 object.")
            ),

            # ── Build path ───────────────────────────────────────────────────
            conditionalPanel("input.om_source == 'build'",

              div(class = "inner-tabs",
                tabsetPanel(

                  # ─── Basic ──────────────────────────────────────────────
                  tabPanel("Basic",
                    br(),
                    div(class = "section-label", "Ages *"),
                    textInput("om_ages", label = NULL, value = "0:20",
                              placeholder = "e.g. 0:20 or c(0,1,2,3,4,5)"),
                    div(class = "helper-text", "R expression — minimum age must be 0"),

                    fluidRow(
                      column(6,
                        div(class = "section-label", "Samples *"),
                        numericInput("om_samples", label = NULL, value = 100, min = 1, step = 1)
                      ),
                      column(6,
                        div(class = "section-label", "Time (years) *"),
                        numericInput("om_time", label = NULL, value = 100, min = 1, step = 1)
                      )
                    ),
                    fluidRow(
                      column(6,
                        div(class = "section-label", "Shape"),
                        numericInput("om_shape", label = NULL, value = NA, step = 0.1),
                        div(class = "helper-text", "Manual shape value — ignored if Target is set")
                      ),
                      column(6,
                        div(class = "section-label", "Seed"),
                        numericInput("om_seed", label = NULL, value = NA, min = 0, step = 1),
                        div(class = "helper-text", "Optional random seed")
                      )
                    ),

                    div(class = "section-divider"),
                    div(class = "section-label", "Target depletion at MNPL"),
                    div(class = "helper-text",
                      "If supplied, ", code("shape()"), " is called after pars are loaded to estimate ",
                      "the shape parameter from this target. Requires ", strong("s, l, b, m, v"),
                      " to be set in the Pars tab. Overrides the manual Shape value above."
                    ),
                    br(),
                    fluidRow(
                      column(6,
                        div(class = "section-label", "Target depletion"),
                        numericInput("om_target", label = NULL, value = NA,
                                     min = 0.4, max = 0.9, step = 0.01),
                        div(class = "helper-text", "Must be between 0.4 and 0.9")
                      ),
                      column(6,
                        div(class = "section-label", "Equilibrium time"),
                        numericInput("om_shape_eq_time", label = NULL, value = 1000,
                                     min = 1, step = 1),
                        div(class = "helper-text", "Time steps used by ", code("shape()"))
                      )
                    ),
                    div(class = "helper-text", style = "margin-top: 6px;",
                      icon("circle-info"),
                      " Estimation of stochastic reference points is only available when running from the command line."
                    )
                  ),

                  # ─── Settings ───────────────────────────────────────────
                  tabPanel("Settings",
                    br(),

                    # CV
                    p(class = "section-label", "Coefficients of Variation  (object@settings$cv)"),
                    div(class = "helper-text", "All default to 0 (deterministic). Set > 0 for stochastic runs."),
                    fluidRow(
                      column(6,
                        numericInput("cv_survivorship", "Survivorship", value = 0, min = 0, step = 0.01)
                      ),
                      column(6,
                        numericInput("cv_birth", "Birth", value = 0, min = 0, step = 0.01)
                      )
                    ),
                    fluidRow(
                      column(6,
                        numericInput("cv_numbers", "Numbers", value = 0, min = 0, step = 0.01)
                      ),
                      column(6,
                        numericInput("cv_harvest_rate", "Harvest rate", value = 0, min = 0, step = 0.01)
                      )
                    ),
                    fluidRow(
                      column(6,
                        numericInput("cv_capture", "Capture", value = 0, min = 0, step = 0.01)
                      ),
                      column(6,
                        numericInput("cv_rmax", "Rmax", value = 0, min = 0, step = 0.01)
                      )
                    ),

                    div(class = "section-divider"),

                    # Bias
                    p(class = "section-label", "Bias  (object@settings$bias)"),
                    div(class = "helper-text", "Multiplicative bias factors. All default to 1.0 (no bias)."),
                    fluidRow(
                      column(6,
                        numericInput("bias_numbers",      "Numbers",      value = 1, min = 0, step = 0.01)
                      ),
                      column(6,
                        numericInput("bias_harvest_rate", "Harvest rate", value = 1, min = 0, step = 0.01)
                      )
                    ),
                    fluidRow(
                      column(6,
                        numericInput("bias_capture", "Capture", value = 1, min = 0, step = 0.01)
                      ),
                      column(6,
                        numericInput("bias_rmax",    "Rmax",    value = 1, min = 0, step = 0.01)
                      )
                    ),

                    div(class = "section-divider"),

                    # Quantiles
                    p(class = "section-label", "Observation Quantiles  (object@settings$qn)"),
                    div(class = "helper-text", "Lower and upper quantile bounds for numbers. Default: 0, NA (no truncation)."),
                    fluidRow(
                      column(6,
                        numericInput("qn_numbers_lo", "Numbers — lower", value = 0, min = 0, max = 1, step = 0.01)
                      ),
                      column(6,
                        numericInput("qn_numbers_hi", "Numbers — upper", value = NA, min = 0, max = 1, step = 0.01)
                      )
                    )
                  ),

                  # ─── Pars ────────────────────────────────────────────────
                  tabPanel("Pars",
                    br(),
                    p(class = "helper-text",
                      "Each parameter is a ", code("distribution"), " object. Supply Par 1 and Par 2 ",
                      "(e.g. mean/SD for normal; mu/sigma for lognormal; shape1/shape2 for beta; ",
                      "min/max for uniform). Leave both blank to keep default (NA)."),

                    par_block_ui("par_s", "s — Adult female survivorship",
                                 "Probability of surviving one year [0, 1]", "lognormal"),
                    par_block_ui("par_l", "l — Age-zero survivorship multiplier",
                                 "Multiplier relative to adult survivorship", "lognormal"),
                    par_block_ui("par_b", "b — Annual births per adult female",
                                 "Fecundity rate > 0", "lognormal"),
                    par_block_ui("par_m", "m — Age at female maturity",
                                 "Non-negative integer (years)", "normal"),
                    div(class = "helper-text", style = "margin-bottom:10px;",
                      icon("circle-info"), " When ", strong("s, l, b"), " and ", strong("m"),
                      " are all supplied, ", code("load_pars()"), " is called automatically and ",
                      code("rmax"), " is derived from them — it cannot be edited directly."
                    ),
                    par_block_ui("par_o", "o — Age at observation",
                                 "Age at which counts are made", "normal"),
                    par_block_ui("par_v", "v — Age at selectivity",
                                 "Age at which fishing selectivity applies", "normal"),
                    par_block_ui("par_K", "K — Carrying capacity",
                                 "Initial carrying capacity (default distribution = 1)", "normal")
                  )
                ) # inner tabsetPanel
              )   # inner-tabs div
            ),    # conditionalPanel build

            hr(),
            actionButton("run_om", "Initialise / Load om", class = "btn-primary btn-block",
                         icon = icon("play")),
            br(),
            uiOutput("dl_om_ui")
          )
        ),

        column(8,
          wellPanel(
            h4("Status"),
            uiOutput("om_status_ui"),
            br(),
            h4("R Output"),
            div(class = "log-box", verbatimTextOutput("om_log"))
          )
        )
      )
    ),

    # ── Tab 2: pdyn ───────────────────────────────────────────────────────────
    tabPanel("2 · pdyn",
      fluidRow(
        column(4,
          wellPanel(
            h4("Arguments"),
            p(class = "helper-text",
              "Uses the ", code("om"), " object built or uploaded in tab 1."),
            fluidRow(
              column(6,
                numericInput("pdyn_iterations", "Iterations", value = 1000, min = 1, step = 1)
              ),
              column(6,
                numericInput("pdyn_time", "Time horizon", value = 100, min = 1, step = 1)
              )
            ),
            numericInput("pdyn_depletion", "Initial Depletion", value = 1.0,
                         min = 0, max = 1, step = 0.01),
            checkboxInput("pdyn_stochastic", "Stochastic", value = TRUE),
            checkboxInput("pdyn_use_rmax",   "Use Rmax",   value = TRUE),
            checkboxInput("pdyn_verbose",    "Verbose",    value = FALSE),
            br(),
            actionButton("run_pdyn", "Run pdyn", class = "btn-primary btn-block",
                         icon = icon("play")),
            br(),
            uiOutput("dl_pdyn_ui")
          )
        ),
        column(8,
          wellPanel(
            h4("Status"),
            uiOutput("pdyn_status_ui"),
            br(),
            h4("R Output / Logs"),
            div(class = "log-box", verbatimTextOutput("pdyn_log"))
          )
        )
      )
    ),

    # ── Tab 3: dynplot ─────────────────────────────────────────────────────────
    tabPanel("3 · dynplot",
      fluidRow(
        column(4,
          wellPanel(
            h4("Plot parameters"),
            p("Uses the pdyn output from tab 2."),
            div(class = "section-label", "Parameters (pars)"),
            textInput("dynplot_pars", label = NULL, value = "depletion",
                      placeholder = "e.g. depletion,captures,harvest_rate"),
            div(class = "helper-text", "Comma-separated: depletion, captures, harvest_rate"),
            br(),
            actionButton("run_dynplot", "Generate Plot", class = "btn-primary btn-block",
                         icon = icon("chart-line")),
            br(),
            uiOutput("dl_plot_ui"),
            hr(),
            uiOutput("dynplot_status_ui")
          )
        ),
        column(8,
          wellPanel(
            plotOutput("dynplot_plot", height = "560px")
          )
        )
      )
    )
  )
)

# ── Server ────────────────────────────────────────────────────────────────────
server <- function(input, output, session) {

  rv <- reactiveValues(
    om_obj        = NULL,
    om_log        = "",
    om_ok         = NA,
    om_shape_vec  = NULL,  # full shape vector from uploaded object; mean shown in UI

    pdyn_obj   = NULL,
    pdyn_log   = "",
    pdyn_ok    = NA,

    plot_obj   = NULL,
    dynplot_ok = NA
  )

  # ── Populate Pars inputs as soon as an om RDS is selected ───────────────────
  observeEvent(input$om_upload, {
    req(input$om_upload)
    tryCatch({
      obj <- readRDS(input$om_upload$datapath)
      if (!is(obj, "om")) stop("not an om object")
      .populate_basic_from_om(session, obj)
      .populate_pars_from_om(session, obj)
      # Preserve the full shape vector; only the mean is shown in the UI box
      if (length(obj@shape) > 0 && !all(is.na(obj@shape))) {
        rv$om_shape_vec <- obj@shape
      }
      showNotification(
        "Basic and Pars tabs populated from uploaded om object.",
        type = "message", duration = 4
      )
    }, error = function(e) {
      # Silent — validation error shown properly when the user clicks the button
    })
  })

  # ── om ──────────────────────────────────────────────────────────────────────
  observeEvent(input$run_om, {
    rv$om_ok  <- NA
    rv$om_log <- ""

    result <- tryCatch({

      # ── Upload path ─────────────────────────────────────────────────────────
      if (input$om_source == "upload") {
        req(input$om_upload)
        obj <- readRDS(input$om_upload$datapath)
        if (!is(obj, "om")) stop("Uploaded file does not contain an 'om' S4 object.")
        # Preserve full shape vector (mean is shown in the UI box)
        if (length(obj@shape) > 0 && !all(is.na(obj@shape))) {
          rv$om_shape_vec <- obj@shape
        }
        shape_note <- if (!is.null(rv$om_shape_vec))
          paste0("  shape: full vector preserved (", length(rv$om_shape_vec),
                 " values, mean = ", round(mean(rv$om_shape_vec, na.rm = TRUE), 4), ")\n")
        else ""
        return(list(ok = TRUE, obj = obj,
                    log = paste0("om object loaded from uploaded RDS.\n", shape_note)))
      }

      # ── Build path ──────────────────────────────────────────────────────────
      log_lines <- character(0)
      add_log   <- function(...) log_lines <<- c(log_lines, paste0(...))

      # Basic arguments
      ages_expr <- trimws(input$om_ages)
      if (ages_expr == "") stop("Ages field is required.")
      ages_val <- eval(parse(text = ages_expr))

      om_args <- list(
        ages    = ages_val,
        samples = as.integer(input$om_samples),
        time    = input$om_time
      )
      if (!is.na(input$om_shape)) om_args$shape <- input$om_shape
      if (!is.na(input$om_seed))  om_args$seeds <- as.integer(input$om_seed)

      add_log("Running om()…")
      obj <- do.call(om, om_args)
      add_log("om() created successfully.")

      # ── Settings: CV ────────────────────────────────────────────────────────
      cv_vals <- list(
        survivorship = input$cv_survivorship,
        birth        = input$cv_birth,
        numbers      = input$cv_numbers,
        harvest_rate = input$cv_harvest_rate,
        capture      = input$cv_capture,
        rmax         = input$cv_rmax
      )
      # Only call load_cvs if any differ from default (0)
      if (any(unlist(cv_vals) != 0)) {
        add_log("Applying CVs via load_cvs()…")
        obj <- load_cvs(obj, cv_vals)
        add_log("  CVs applied.")
      }

      # ── Settings: Bias ──────────────────────────────────────────────────────
      bias_vals <- list(
        numbers      = input$bias_numbers,
        harvest_rate = input$bias_harvest_rate,
        capture      = input$bias_capture,
        rmax         = input$bias_rmax
      )
      if (any(unlist(bias_vals) != 1)) {
        add_log("Applying bias via load_bias()…")
        obj <- load_bias(obj, bias_vals)
        add_log("  Bias applied.")
      }

      # ── Settings: Quantiles ─────────────────────────────────────────────────
      qn_lo <- input$qn_numbers_lo
      qn_hi <- input$qn_numbers_hi
      if (!is.na(qn_lo) || !is.na(qn_hi)) {
        qn_lo <- if (is.na(qn_lo)) 0 else qn_lo
        add_log("Applying quantiles via load_quantiles()…")
        obj <- load_quantiles(obj, list(numbers = c(qn_lo, qn_hi)))
        add_log("  Quantiles applied.")
      }

      # ── Pars ────────────────────────────────────────────────────────────────
      par_map <- list(
        s = list(prefix = "par_s", name = "adult female survivorship"),
        l = list(prefix = "par_l", name = "age-zero survivorship multiplier"),
        b = list(prefix = "par_b", name = "annual births per adult female"),
        m = list(prefix = "par_m", name = "age at female maturity"),
        o = list(prefix = "par_o", name = "age at observation"),
        v = list(prefix = "par_v", name = "age at selectivity"),
        K = list(prefix = "par_K", name = "carrying capacity")
      )

      pars_to_load <- list()
      for (par_name in names(par_map)) {
        info   <- par_map[[par_name]]
        p1_id  <- paste0(info$prefix, "_p1")
        p2_id  <- paste0(info$prefix, "_p2")
        dn_id  <- paste0(info$prefix, "_dens")
        dist   <- .build_dist(input[[p1_id]], input[[p2_id]], input[[dn_id]], name = info$name)
        if (!is.null(dist)) {
          pars_to_load[[par_name]] <- dist
          add_log("  Par '", par_name, "' (", info$name, ") loaded.")
        }
      }

      if (length(pars_to_load) > 0) {
        add_log("Applying pars via load_pars()…")
        obj <- load_pars(obj, pars_to_load)
        add_log("  Pars applied.")

        # When s, l, b and m are all supplied, load_pars() calculates r
        # automatically.  Follow up with load_rmax() (no value arg) so that
        # rmax is derived from r — the user cannot set rmax directly.
        slbm_provided <- all(c("s", "l", "b", "m") %in% names(pars_to_load))
        if (slbm_provided) {
          add_log("  s, l, b, m all provided — deriving rmax from r via load_rmax()…")
          obj <- load_rmax(obj)   # uses object@pars$r calculated by load_pars
          add_log("  rmax derived and loaded.")
        }
      }

      # ── Shape via target depletion ──────────────────────────────────────────
      target_val <- input$om_target
      if (!is.na(target_val)) {
        if (target_val < 0.4 || target_val > 0.9)
          stop("Target depletion must be between 0.4 and 0.9.")
        eq_time <- as.integer(input$om_shape_eq_time)
        add_log("\nEstimating shape from target depletion = ", target_val,
                " (stochastic = FALSE, equilibrium time = ", eq_time, ") via shape()…")
        add_log("  Note: requires s, l, b, m, v to be set in Pars tab.")
        shape_log <- capture.output({
          obj <- shape(obj,
                       depletion  = target_val,
                       stochastic = FALSE,
                       time       = eq_time)
        })
        if (length(shape_log) > 0) add_log(paste(shape_log, collapse = "\n"))
        add_log("  Shape estimated: mean = ", round(mean(obj@shape, na.rm = TRUE), 4),
                ", stored in object@shape.")
      }

      add_log("\nom object ready.")
      list(ok = TRUE, obj = obj, log = paste(log_lines, collapse = "\n"))

    }, error = function(e) {
      list(ok = FALSE, obj = NULL, log = paste0("Error:\n", conditionMessage(e), "\n"))
    })

    rv$om_obj <- result$obj
    rv$om_log <- result$log
    rv$om_ok  <- result$ok

    if (isTRUE(result$ok)) {
      updateRadioButtons(session, "om_source", selected = "build")
      showNotification("om object ready — switching to pdyn tab.", type = "message", duration = 4)
      updateTabsetPanel(session, "main_tabs", selected = "2 · pdyn")
    }
  })

  output$om_status_ui <- renderUI({
    if (is.na(rv$om_ok))  return(span("Not yet run.", style = "color:#6b7280"))
    if (isTRUE(rv$om_ok)) return(span("✓ om object ready.", class = "status-ok"))
    span("✗ Error — see R Output below.", class = "status-err")
  })
  output$om_log <- renderText({ rv$om_log })

  output$dl_om_ui <- renderUI({
    if (is.null(rv$om_obj))
      tags$button("Download om RDS", class = "btn btn-success btn-block", disabled = NA)
    else
      downloadButton("dl_om", "Download om RDS", class = "btn-success btn-block")
  })

  output$dl_om <- downloadHandler(
    filename = function() paste0("om_output_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".rds"),
    content  = function(file) {
      if (is.null(rv$om_obj)) return()
      saveRDS(rv$om_obj, file)
    }
  )

  # ── pdyn ────────────────────────────────────────────────────────────────────
  observeEvent(input$run_pdyn, {
    rv$pdyn_ok  <- NA
    rv$pdyn_log <- "Running pdyn()…\n"

    if (is.null(rv$om_obj)) {
      rv$pdyn_log <- "Error: No om object found. Complete tab 1 first."
      rv$pdyn_ok  <- FALSE
      return()
    }

    result <- tryCatch({
      pdyn_args <- list(
        object      = rv$om_obj,
        stochastic  = input$pdyn_stochastic,
        verbose     = input$pdyn_verbose,
        use_rmax    = input$pdyn_use_rmax
      )
      if (!is.na(input$pdyn_iterations)) pdyn_args$iterations       <- as.integer(input$pdyn_iterations)
      if (!is.na(input$pdyn_time))       pdyn_args$time              <- input$pdyn_time
      if (!is.na(input$pdyn_depletion))  pdyn_args$initial_depletion <- input$pdyn_depletion

      log_text <- capture.output({ obj <- do.call(pdyn, pdyn_args) })
      list(ok = TRUE, obj = obj,
           log = paste(c("pdyn() completed successfully.", log_text), collapse = "\n"))
    }, error = function(e) {
      list(ok = FALSE, obj = NULL, log = paste0("Error in pdyn():\n", conditionMessage(e), "\n"))
    })

    rv$pdyn_obj <- result$obj
    rv$pdyn_log <- result$log
    rv$pdyn_ok  <- result$ok

    if (isTRUE(result$ok)) {
      showNotification("pdyn complete — switching to dynplot tab.", type = "message", duration = 4)
      updateTabsetPanel(session, "main_tabs", selected = "3 · dynplot")
    }
  })

  output$pdyn_status_ui <- renderUI({
    if (is.na(rv$pdyn_ok))   return(span("Not yet run.", style = "color:#6b7280"))
    if (isTRUE(rv$pdyn_ok))  return(span("✓ pdyn result ready.", class = "status-ok"))
    span("✗ Error — see R Output below.", class = "status-err")
  })
  output$pdyn_log <- renderText({ rv$pdyn_log })

  output$dl_pdyn_ui <- renderUI({
    if (is.null(rv$pdyn_obj))
      tags$button("Download pdyn RDS", class = "btn btn-success btn-block", disabled = NA)
    else
      downloadButton("dl_pdyn", "Download pdyn RDS", class = "btn-success btn-block")
  })

  output$dl_pdyn <- downloadHandler(
    filename = function() paste0("pdyn_output_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".rds"),
    content  = function(file) {
      if (is.null(rv$pdyn_obj)) return()
      saveRDS(rv$pdyn_obj, file)
    }
  )

  # ── dynplot ─────────────────────────────────────────────────────────────────
  observeEvent(input$run_dynplot, {
    rv$dynplot_ok <- NA

    if (is.null(rv$pdyn_obj)) {
      showNotification("No pdyn result — run tab 2 first.", type = "error", duration = 5)
      rv$dynplot_ok <- FALSE
      return()
    }

    result <- tryCatch({
      dynplot_args <- list(object = rv$pdyn_obj)
      pars_raw <- trimws(input$dynplot_pars)
      if (nchar(pars_raw) > 0) {
        pars_vec <- trimws(strsplit(pars_raw, ",")[[1]])
        pars_vec <- pars_vec[nchar(pars_vec) > 0]
        if (length(pars_vec) > 0) dynplot_args$pars <- pars_vec
      }
      p <- do.call(dynplot, dynplot_args)
      list(ok = TRUE, plot = p)
    }, error = function(e) {
      showNotification(paste0("Error in dynplot(): ", e$message), type = "error", duration = 8)
      list(ok = FALSE, plot = NULL)
    })

    rv$plot_obj   <- result$plot
    rv$dynplot_ok <- result$ok
  })

  output$dynplot_status_ui <- renderUI({
    if (is.na(rv$dynplot_ok))  return(span("Not yet run.", style = "color:#6b7280"))
    if (isTRUE(rv$dynplot_ok)) return(span("✓ Plot ready.", class = "status-ok"))
    span("✗ Error generating plot.", class = "status-err")
  })

  output$dynplot_plot <- renderPlot({
    req(rv$plot_obj)
    print(rv$plot_obj)
  })

  output$dl_plot_ui <- renderUI({
    if (is.null(rv$plot_obj))
      tags$button("Download PNG", class = "btn btn-success btn-block", disabled = NA)
    else
      downloadButton("dl_plot", "Download PNG", class = "btn-success btn-block")
  })

  output$dl_plot <- downloadHandler(
    filename = function() paste0("dynplot_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".png"),
    content  = function(file) {
      if (is.null(rv$plot_obj)) return()
      ggplot2::ggsave(file, plot = rv$plot_obj, width = 10, height = 7, dpi = 150, bg = "white")
    }
  )
}

# ── Run ───────────────────────────────────────────────────────────────────────
shinyApp(ui = ui, server = server)
