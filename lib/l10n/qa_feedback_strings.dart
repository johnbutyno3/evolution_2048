import 'package:flutter/widgets.dart';

class QaFeedbackStrings {
  QaFeedbackStrings._(this.isChinese);

  final bool isChinese;

  static QaFeedbackStrings of(BuildContext context) =>
      QaFeedbackStrings._(Localizations.localeOf(context).languageCode == 'zh');

  String get qaTitle => isChinese ? '常見問題' : 'Q&A';
  String get qaHeading => isChinese ? '常見問題集' : 'Frequently Asked Questions';
  String get qaQuestion1 => isChinese ? '如何遊玩重生 2048？' : 'How do I play Rebirth 2048?';
  String get qaAnswer1 => isChinese ? '滑動棋盤或使用鍵盤移動生命形態。合併相同的生命形態即可進化到下一階段，達成章節目標即可前進。' : 'Swipe or use the keyboard to move life forms. Matching life forms evolve into the next stage. Reach the chapter target to progress.';
  String get qaQuestion2 => isChinese ? '發現生物後會怎樣？' : 'What happens when I discover a creature?';
  String get qaAnswer2 => isChinese ? '已發現的生物會記錄在生物圖鑑中，重新遊玩或重置後仍會保留。' : 'A discovered creature is recorded in your Creature Collection and remains unlocked after replaying or restarting.';
  String get qaQuestion3 => isChinese ? '生命值是什麼？' : 'What are Lives?';
  String get qaAnswer3 => isChinese ? '生命值用於開始遊戲挑戰。會員權益可能會影響生命值規則。' : 'Lives allow you to continue playing after a game ends. Membership benefits may change the available life rules.';
  String get qaQuestion4 => isChinese ? '金幣是什麼？' : 'What is Gold?';
  String get qaAnswer4 => isChinese ? '金幣是遊戲內貨幣，可用於商城購買生命值及進化道具等商品。' : 'Gold is the in-game currency used for eligible shop purchases such as Lives and Evolution Tools.';
  String get qaQuestion5 => isChinese ? '進化道具有什麼用途？' : 'What do the Evolution Tools do?';
  String get qaAnswer5 => isChinese ? 'UNDO 可復原一步；REMOVE 可移除指定生命形態；SWAP 可交換位置；DUPLICATE 可複製指定生命形態。' : 'UNDO rewinds a move, REMOVE removes a selected life form, SWAP exchanges positions, and DUPLICATE creates a copy of a selected life form.';
  String get qaQuestion6 => isChinese ? '如何回報問題？' : 'How do I report a problem?';
  String get qaAnswer6 => isChinese ? '請在個人頁面開啟「聯絡／意見回饋」，選擇「錯誤回報」，描述問題後送出給遊戲團隊。' : 'Open Contact / Feedback from your Personal page, choose Bug Report, describe the problem and send it to the game team.';

  String get feedbackTitle => isChinese ? '聯絡／意見回饋' : 'Contact / Feedback';
  String get feedbackHeading => isChinese ? '傳送訊息' : 'Send a message';
  String get feedbackDescription => isChinese ? '歡迎提出問題、建議或錯誤回報。' : 'Questions, suggestions and bug reports are welcome.';
  String get feedbackType => isChinese ? '類別' : 'Type';
  String get feedbackQuestion => isChinese ? '問題' : 'Question';
  String get feedbackSuggestion => isChinese ? '建議' : 'Suggestion';
  String get feedbackBugReport => isChinese ? '錯誤回報' : 'Bug Report';
  String get feedbackOther => isChinese ? '其他' : 'Other';
  String get feedbackMessage => isChinese ? '訊息內容' : 'Message';
  String get feedbackSend => isChinese ? '送出訊息' : 'Send Message';
  String get feedbackSending => isChinese ? '傳送中…' : 'Sending...';
  String get feedbackSent => isChinese ? '訊息已成功送出。' : 'Your message has been sent.';
  String get feedbackSendFailed => isChinese ? '無法送出訊息，請稍後再試。' : 'Unable to send your message. Please try again.';
  String get feedbackEmpty => isChinese ? '請先輸入訊息內容再送出。' : 'Please enter a message before sending.';
  String get feedbackSignInRequired => isChinese ? '請先登入，再傳送意見回饋。' : 'Sign in to send feedback.';
}
