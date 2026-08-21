import '../../../core/network/api_client.dart';
import 'content_models.dart';

class ContentRepository {
  const ContentRepository(this._api);

  final ApiClient _api;

  Future<List<CmsDocument>> documents({String locale = 'en'}) async {
    final rows = await _api.select(
      'cms_documents',
      columns: 'id, kind, locale, title, body, version, effective_from',
      filter: (query) =>
          query.eq('is_published', true).eq('locale', locale).order('kind'),
    );
    return rows.map(CmsDocument.fromJson).toList(growable: false);
  }

  Future<List<CmsFaq>> faqs({String locale = 'en'}) async {
    final rows = await _api.select(
      'cms_faqs',
      columns: 'id, category, question, answer, locale, display_order',
      filter: (query) => query
          .eq('is_published', true)
          .eq('locale', locale)
          .order('category')
          .order('display_order'),
    );
    return rows.map(CmsFaq.fromJson).toList(growable: false);
  }
}
