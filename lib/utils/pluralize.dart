/// The noun for [count]: [singular] when [count] is exactly 1, otherwise [plural].
String pluralize(int count, String singular, String plural) => count == 1 ? singular : plural;
