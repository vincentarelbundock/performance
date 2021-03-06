#' @title Check model for (non-)normality of residuals.
#' @name check_normality
#'
#' @description Check model for (non-)normality of residuals.
#'
#' @param x A model object.
#' @param effects Should normality for residuals (\code{"fixed"}) or random
#' effects (\code{"random"}) be tested? Only applies to mixed models. May
#' be abbreviated.
#' @param ... Currently not used.
#'
#' @return Invisibly returns the p-value of the test statistics. A p-value
#' < 0.05 indicates a significant deviation from normal distribution
#'
#' @note For mixed models, studentized residuals are used for the test, \emph{not} the standardized residuals. There is also a \href{https://easystats.github.io/see/articles/performance.html}{\code{plot()}-method} implemented in the \href{https://easystats.github.io/see/}{\pkg{see}-package}.
#'
#' @details \code{check_normality()} calls \code{stats::shapiro.test}
#' and checks the standardized residuals (or studentized residuals for mixed
#' models) for normal distribution. Note that this formal test almost always
#' yields significant results for the distribution of residuals and visual
#' inspection (e.g. Q-Q plots) are preferable.
#'
#' @examples
#' m <- lm(mpg ~ wt + cyl + gear + disp, data = mtcars)
#' check_normality(m)
#'
#' # plot results
#' if (require("see")) {
#'   x <- check_normality(m)
#'   plot(x)
#' }
#' \dontrun{
#' # QQ-plot
#' plot(check_normality(m), type = "qq")
#'
#' # PP-plot
#' plot(check_normality(m), type = "pp")
#' }
#' @importFrom stats shapiro.test rstandard rstudent
#' @export
check_normality <- function(x, ...) {
  UseMethod("check_normality")
}


#' @export
check_normality.default <- function(x, ...) {
  # check for normality of residuals
  p.val <- .check_normality(stats::rstandard(x), x)

  attr(p.val, "object_name") <- .safe_deparse(substitute(x))
  attr(p.val, "effects") <- "fixed"
  class(p.val) <- unique(c("check_normality", "see_check_normality", class(p.val)))

  invisible(p.val)
}





# mixed models ---------------------


#' @rdname check_normality
#' @export
check_normality.merMod <- function(x, effects = c("fixed", "random"), ...) {
  # args
  effects <- match.arg(effects)
  info <- insight::model_info(x)

  if (effects == "random") {
    if (!requireNamespace("lme4", quietly = TRUE)) {
      stop("Package 'lme4' required for this function to work. Please install it.", call. = FALSE)
    }

    re <- tryCatch(
      {
        if (inherits(x, "glmmTMB")) {
          var_attr <- "condVar"
          .collapse_cond(lme4::ranef(x, condVar = TRUE))
        } else {
          var_attr <- "postVar"
          lme4::ranef(x, condVar = TRUE)
        }
      },
      error = function(e) {
        return(NULL)
      }
    )

    p.val <- c()
    re_len <- max(nchar(unlist(lapply(re, colnames))))

    if (!is.null(re)) {
      for (i in names(re)) {
        insight::print_color(sprintf("Group: %s\n", i), "blue")
        for (j in colnames(re[[i]])) {
          cat(sprintf("%*s ", re_len, j))
          p.val <- c(p.val, .check_normality(re[[i]][[j]], x, "random effects"))
        }
        cat("\n")
      }
      attr(p.val, "re_qq") <- .diag_reqq(x, level = .95, model_info = info)
    }
  } else {
    # check for normality of residuals
    p.val <- .check_normality(stats::rstudent(x), x)
  }

  attr(p.val, "object_name") <- .safe_deparse(substitute(x))
  attr(p.val, "effects") <- effects
  class(p.val) <- unique(c("check_normality", "see_check_normality", class(p.val)))

  invisible(p.val)
}


#' @export
check_normality.glmmTMB <- check_normality.merMod






# helper ---------------------


#' @importFrom insight print_color format_p
.check_normality <- function(x, model, type = "residuals") {
  ts <- tryCatch(
    {
      stats::shapiro.test(x)
    },
    error = function(e) {
      NULL
    }
  )

  if (is.null(ts)) {
    insight::print_color(sprintf("'check_normality()' does not support models of class '%s'.\n", class(model)[1]), "red")
    return(NULL)
  }

  # format p-value
  p.val <- ts$p.value
  pstring <- insight::format_p(p.val)

  if (p.val < 0.05) {
    insight::print_color(sprintf("Warning: Non-normality of %s detected (%s).\n", type, pstring), "red")
  } else {
    insight::print_color(sprintf("OK: %s appear as normally distributed (%s).\n", type, pstring), "green")
  }

  p.val
}
