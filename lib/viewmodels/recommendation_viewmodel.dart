import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/food_repository.dart';
import '../models/food.dart';
import '../models/user_profile.dart';
import 'diary_viewmodel.dart';
import 'dart:async';
class Recommendation { final Food food; final double score; final String reason; Recommendation(this.food, this.score, this.reason); }
class RecommendationViewModel extends ChangeNotifier {
  RecommendationViewModel(this._repo, this._client);
  final FoodRepository _repo; final SupabaseClient _client; List<Recommendation> _items=[]; String? _lastSignature; String? _pendingSignature; List<Food>? _cachedFoods; Timer? _generationTimer; bool _signedIn = false;
  List<Recommendation> get items => _items;
  /// Makes a newly created food available without requiring an app restart.
  void addCustomFood(Food food) {
    if (_cachedFoods != null && !_cachedFoods!.any((item) => item.id == food.id)) {
      _cachedFoods = [..._cachedFoods!, food];
    }
    _lastSignature = null;
  }
  void setSession(bool signedIn) { if (_signedIn == signedIn) return; _signedIn = signedIn; if (!signedIn) { _generationTimer?.cancel(); _items=[]; _lastSignature=null; _pendingSignature=null; notifyListeners(); } }
  Future<void> generate(UserProfile p, DiaryViewModel diary, {String trigger = 'profile_change'}) async {
    if (!_signedIn) return;
    final allergies = p.allergies.toList()..sort();
    final dislikes = p.dislikedFoods.toList()..sort();
    final signature='${p.goal.code}:${p.diet.name}:${allergies.join(',')}:${dislikes.join(',')}:${diary.totalCalories.round()}:${diary.totalProtein.round()}';
    if ((signature == _lastSignature || signature == _pendingSignature) && trigger != 'manual') return;
    if (trigger != 'manual') {
      _generationTimer?.cancel(); _pendingSignature = signature;
      _generationTimer = Timer(const Duration(milliseconds: 350), () { if (_pendingSignature == signature) unawaited(_generateNow(p, diary, trigger, signature)); });
      return;
    }
    await _generateNow(p, diary, trigger, signature);
  }
  Future<void> _generateNow(UserProfile p, DiaryViewModel diary, String trigger, String signature) async {
    try {
    final foods = _cachedFoods ??= await _repo.loadFoods(); final out=<Recommendation>[];
    final remaining=(p.calorieTarget-diary.totalCalories).clamp(0.0, double.infinity);
    for(final f in foods) {
      final text='${f.name} ${f.description}'.toLowerCase();
      if(f.allergens.any(p.allergies.contains)||p.allergies.any((a)=>text.contains(a.toLowerCase()))||p.dislikedFoods.any((d)=>f.name.toLowerCase().contains(d.toLowerCase()))) continue;
      if(p.diet!=DietPreference.none&&!f.dietTags.contains(p.diet.name)&&!(p.diet==DietPreference.vegetarian&&f.dietTags.contains('vegan'))) continue;
      var score=_score(f,p.goal); if(f.calories>remaining&&remaining>0) score*=.65; if(score>0) out.add(Recommendation(f,score,_reason(f,p.goal,remaining)));
    }
    out.sort((a,b)=>b.score.compareTo(a.score)); _items=out.take(5).toList(); _lastSignature=signature; notifyListeners();
    if (_client.auth.currentUser != null) await _client.rpc('record_recommendation_event', params: {'p_trigger_type':trigger, 'p_input_signature':signature, 'p_daily_calories_kcal':diary.totalCalories, 'p_recommendations':_items.map((r)=>{'food_id':r.food.id,'score':r.score,'reason':r.reason}).toList()});
    } finally { if (_pendingSignature == signature) _pendingSignature = null; }
  }
  double _score(Food f,FitnessGoal g)=>switch(g){FitnessGoal.muscle=>f.calories==0?0:f.protein*400/f.calories,FitnessGoal.weightLoss=>200/(f.calories/(f.protein+f.fiber+1)+1),FitnessGoal.weightGain=>f.calories/3,FitnessGoal.fiber=>f.fiber*10,FitnessGoal.balanced=>((f.protein>3?1:0)+(f.fiber>2?1:0)+(f.fat<10?1:0)+(f.sodium<300?1:0))*25.0};
  String _reason(Food f,FitnessGoal g,double remaining)=>'${g.label}: ${f.protein.toStringAsFixed(0)} g protein, ${f.fiber.toStringAsFixed(1)} g fiber; ${remaining.toStringAsFixed(0)} kcal remaining today.';
  @override void dispose() { _generationTimer?.cancel(); super.dispose(); }
}
