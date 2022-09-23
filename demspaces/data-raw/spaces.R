
spaces <- tibble::tribble(
  ~Space, ~Indicator, ~Description,
  "Electoral",     "v2x_veracc_osp", "The ability of the population to hold their government accountable through elections and political parties. Measured using the vertical accountability index",
  "Associational", "v2xcs_ccsi", "The degree of CSO autonomy from the state and citizens' ability to freely and actively pursue their political and civic goals. Measured with the core civil society index.",
  "Individual",    "v2xcl_rol", "The extent to which the laws are transparent and rigorously enforced and public administration impartial, and the extent to which citizens enjoy access to justice, secure property rights, freedom from forced labor, freedom of movement, physical integrity rights, and freedom of religion. Measured with the rule of law index",
  "Informational", "v2x_freexp_altinf", "The degree of media censorship, harassment of journalists, media bias, media self-censorship, whether the media is critical and pluralistic, as well as the freedom of discussion and academic and cultural expression. Measured with the freedom of expression and alternative sources of information index.",
  "Governing",     "v2x_horacc_osp", "The degree to which the legislative and judicial branches can hold the executive branch accountable as well as legislative and judical oversight over the bureaucracy and security services. Measured using the horizontal accountability index.",
  "Economic",      "v2x_pubcorr", "Absence of public corruption. The extent to which public sector employees grant favors in exchange for bribes (or other material inducements), and how often they steal, embezzle, or misappropriate public funds or other state resources for personal or family use. Note that this is inverted from the original V-Dem variable so that high values indicate absence of public corruption."
)

usethis::use_data(spaces, overwrite = TRUE)
