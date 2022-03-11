/// Annotation used to indicate that a class should be populated by a vocabulary
class Vocab {
  final String uri;
  final String? prefix;

  const Vocab(this.uri, {this.prefix});
}
