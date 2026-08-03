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

# ── UI ────────────────────────────────────────────────────────────────────────
ui <- fluidPage(
  title = "pstom Interface",

  tags$head(tags$style(HTML("
    body { font-family: 'Segoe UI', Arial, sans-serif; background: #f8f9fa; }
    .navbar-header { padding: 12px 16px; }
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
      max-height: 260px; overflow-y: auto; white-space: pre-wrap;
    }
    .status-ok   { color: #16a34a; font-weight: 600; }
    .status-err  { color: #dc2626; font-weight: 600; }
    .status-run  { color: #d97706; font-weight: 600; }
    .section-label { font-weight: 600; font-size: 13px; margin-bottom: 4px; color: #374151; }
    .helper-text { font-size: 11px; color: #6b7280; margin-top: 2px; }
  "))),

  h1("pstom R Interface", class = "app-title"),

  tabsetPanel(id = "main_tabs",
    # ── Tab 1: om ─────────────────────────────────────────────────────────────
    tabPanel("1 · om",
      fluidRow(
        column(4,
          wellPanel(
            h4("Initialise operating model"),
            p("Creates an ", code("om"), " S4 object using ", code("pstom::om()"), "."),
            hr(),
            div(class = "section-label", "Ages *"),
            textInput("om_ages", label = NULL, value = "1:20",
                      placeholder = "e.g. 1:20 or c(1,2,3,4,5)"),
            div(class = "helper-text", "Any R integer vector expression"),
            br(),
            fluidRow(
              column(6,
                div(class = "section-label", "Samples"),
                numericInput("om_samples", label = NULL, value = NA, min = 1, step = 1),
                div(class = "helper-text", "Monte Carlo samples")
              ),
              column(6,
                div(class = "section-label", "Time (years)"),
                numericInput("om_time", label = NULL, value = NA, min = 1, step = 1),
                div(class = "helper-text", "Time horizon")
              )
            ),
            fluidRow(
              column(6,
                div(class = "section-label", "Shape"),
                numericInput("om_shape", label = NULL, value = NA, step = 0.1),
                div(class = "helper-text", "Shape parameter")
              ),
              column(6,
                div(class = "section-label", "Seed"),
                numericInput("om_seed", label = NULL, value = NA, min = 0, step = 1),
                div(class = "helper-text", "Random seed")
              )
            ),
            br(),
            actionButton("run_om", "Initialise om", class = "btn-primary btn-block",
                         icon = icon("play")),
            br(),
            downloadButton("dl_om", "Download om RDS", class = "btn-success btn-block")
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
            h4("Input object"),
            radioButtons("pdyn_source", label = NULL,
              choices = list(
                "Use om object from tab 1" = "from_om",
                "Upload an RDS file"       = "upload"
              ),
              selected = "from_om"
            ),
            conditionalPanel("input.pdyn_source == 'upload'",
              fileInput("pdyn_upload", label = NULL, accept = c(".rds", ".RDS", ".rda", ".RDA"),
                        buttonLabel = "Browse…", placeholder = "No file selected")
            ),
            hr(),
            h4("Arguments"),
            fluidRow(
              column(6,
                numericInput("pdyn_iterations", "Iterations", value = 1000, min = 1, step = 1)
              ),
              column(6,
                numericInput("pdyn_time", "Time horizon", value = 100, min = 1, step = 1)
              )
            ),
            numericInput("pdyn_depletion", "Initial Depletion", value = 0.1,
                         min = 0, max = 1, step = 0.01),
            checkboxInput("pdyn_stochastic", "Stochastic", value = TRUE),
            checkboxInput("pdyn_use_rmax",   "Use Rmax",   value = TRUE),
            checkboxInput("pdyn_verbose",    "Verbose",    value = FALSE),
            br(),
            actionButton("run_pdyn", "Run pdyn", class = "btn-primary btn-block",
                         icon = icon("play")),
            br(),
            downloadButton("dl_pdyn", "Download pdyn RDS", class = "btn-success btn-block")
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
            textInput("dynplot_pars", label = NULL, value = "N,B,F",
                      placeholder = "e.g. N,B,F"),
            div(class = "helper-text", "Comma-separated (N: Numbers, B: Biomass, F: Fishing Mortality)"),
            br(),
            actionButton("run_dynplot", "Generate Plot", class = "btn-primary btn-block",
                         icon = icon("chart-line")),
            br(),
            downloadButton("dl_plot", "Download PNG", class = "btn-success btn-block"),
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

  # Reactive state
  rv <- reactiveValues(
    om_obj     = NULL,  # om S4 object
    om_log     = "",
    om_ok      = NA,    # TRUE / FALSE / NA (not yet run)

    pdyn_obj   = NULL,  # pdyn output S4 object
    pdyn_log   = "",
    pdyn_ok    = NA,

    plot_obj   = NULL,  # ggplot2 plot
    dynplot_ok = NA
  )

  # ── om ──────────────────────────────────────────────────────────────────────
  observeEvent(input$run_om, {
    rv$om_ok  <- NA
    rv$om_log <- "Running om()…\n"

    ages_expr <- trimws(input$om_ages)
    if (ages_expr == "") { rv$om_log <- "Error: Ages field is required."; rv$om_ok <- FALSE; return() }

    result <- tryCatch({
      om_args <- list(ages = eval(parse(text = ages_expr)))
      if (!is.na(input$om_samples) && !is.null(input$om_samples))
        om_args$samples <- as.integer(input$om_samples)
      if (!is.na(input$om_time)    && !is.null(input$om_time))
        om_args$time    <- input$om_time
      if (!is.na(input$om_shape)   && !is.null(input$om_shape))
        om_args$shape   <- input$om_shape
      if (!is.na(input$om_seed)    && !is.null(input$om_seed))
        om_args$seeds   <- as.integer(input$om_seed)
      obj <- do.call(om, om_args)
      list(ok = TRUE, obj = obj, log = "om() completed successfully.\n")
    }, error = function(e) {
      list(ok = FALSE, obj = NULL, log = paste0("Error in om():\n", conditionMessage(e), "\n"))
    })

    rv$om_obj <- result$obj
    rv$om_log <- result$log
    rv$om_ok  <- result$ok

    if (result$ok) {
      showNotification("om object created — switching to pdyn tab.", type = "message", duration = 4)
      updateTabsetPanel(session, "main_tabs", selected = "2 · pdyn")
    }
  })

  output$om_status_ui <- renderUI({
    if (is.na(rv$om_ok))  return(span("Not yet run.", style = "color:#6b7280"))
    if (rv$om_ok)         return(span("✓ om object ready.", class = "status-ok"))
    span("✗ Error — see R Output below.", class = "status-err")
  })
  output$om_log <- renderText({ rv$om_log })

  output$dl_om <- downloadHandler(
    filename = function() paste0("om_output_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".rds"),
    content  = function(file) {
      req(rv$om_obj)
      saveRDS(rv$om_obj, file)
    }
  )

  # ── pdyn ────────────────────────────────────────────────────────────────────
  observeEvent(input$run_pdyn, {
    rv$pdyn_ok  <- NA
    rv$pdyn_log <- "Running pdyn()…\n"

    # Resolve input object
    input_obj <- if (input$pdyn_source == "from_om") {
      if (is.null(rv$om_obj)) {
        rv$pdyn_log <- "Error: No om object. Run tab 1 first, or switch to 'Upload an RDS file'."
        rv$pdyn_ok  <- FALSE
        return()
      }
      rv$om_obj
    } else {
      req(input$pdyn_upload)
      tryCatch(readRDS(input$pdyn_upload$datapath),
               error = function(e) { rv$pdyn_log <- paste0("Error reading RDS: ", e$message); rv$pdyn_ok <- FALSE; NULL })
    }
    if (is.null(input_obj)) return()

    result <- tryCatch({
      pdyn_args <- list(
        object      = input_obj,
        stochastic  = input$pdyn_stochastic,
        verbose     = input$pdyn_verbose,
        use_rmax    = input$pdyn_use_rmax
      )
      if (!is.na(input$pdyn_iterations)) pdyn_args$iterations       <- as.integer(input$pdyn_iterations)
      if (!is.na(input$pdyn_time))       pdyn_args$time              <- input$pdyn_time
      if (!is.na(input$pdyn_depletion))  pdyn_args$initial_depletion <- input$pdyn_depletion

      # Capture verbose output
      log_text <- capture.output({
        obj <- do.call(pdyn, pdyn_args)
      })
      list(ok = TRUE, obj = obj,
           log = paste(c("pdyn() completed successfully.", log_text), collapse = "\n"))
    }, error = function(e) {
      list(ok = FALSE, obj = NULL, log = paste0("Error in pdyn():\n", conditionMessage(e), "\n"))
    })

    rv$pdyn_obj <- result$obj
    rv$pdyn_log <- result$log
    rv$pdyn_ok  <- result$ok

    if (result$ok) {
      showNotification("pdyn complete — switching to dynplot tab.", type = "message", duration = 4)
      updateTabsetPanel(session, "main_tabs", selected = "3 · dynplot")
    }
  })

  output$pdyn_status_ui <- renderUI({
    if (is.na(rv$pdyn_ok))  return(span("Not yet run.", style = "color:#6b7280"))
    if (rv$pdyn_ok)         return(span("✓ pdyn result ready.", class = "status-ok"))
    span("✗ Error — see R Output below.", class = "status-err")
  })
  output$pdyn_log <- renderText({ rv$pdyn_log })

  output$dl_pdyn <- downloadHandler(
    filename = function() paste0("pdyn_output_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".rds"),
    content  = function(file) {
      req(rv$pdyn_obj)
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
    if (rv$dynplot_ok)         return(span("✓ Plot ready.", class = "status-ok"))
    span("✗ Error generating plot.", class = "status-err")
  })

  output$dynplot_plot <- renderPlot({
    req(rv$plot_obj)
    print(rv$plot_obj)
  })

  output$dl_plot <- downloadHandler(
    filename = function() paste0("dynplot_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".png"),
    content  = function(file) {
      req(rv$plot_obj)
      ggplot2::ggsave(file, plot = rv$plot_obj, width = 10, height = 7, dpi = 150, bg = "white")
    }
  )
}

# ── Run ───────────────────────────────────────────────────────────────────────
shinyApp(ui = ui, server = server)
