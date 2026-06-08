// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get enterMasterKey => 'Введите мастер-ключ';

  @override
  String get masterKeyLabel => 'Мастер-ключ';

  @override
  String get unlock => 'Разблокировать';

  @override
  String get masterKeyHint =>
      'Мастер-ключ не сохраняется; его нужно вводить заново при каждом запуске.\nОставьте поле пустым, чтобы использовать один пробел в качестве ключа (совместимо со старой версией).';

  @override
  String get settings => 'Настройки';

  @override
  String get lock => 'Заблокировать';

  @override
  String get tabQuery => 'Поиск';

  @override
  String get tabAdd => 'Добавить';

  @override
  String get tabList => 'Список';

  @override
  String get syncIdle => 'Не синхронизировано';

  @override
  String get syncWorking => 'Синхронизация…';

  @override
  String get syncOk => 'Синхронизировано';

  @override
  String get syncOffline => 'Не в сети';

  @override
  String get syncError => 'Ошибка синхронизации';

  @override
  String get queryFieldLabel =>
      'Сайт (поддерживается частичное совпадение по ключевым словам)';

  @override
  String get queryInvalidKey =>
      'Неверный мастер-ключ: совпадающий сайт найден, но расшифровать нельзя';

  @override
  String get queryNoMatch => 'Совпадающие записи не найдены';

  @override
  String get queryPrompt => 'Введите сайт и нажмите Enter для поиска';

  @override
  String get edit => 'Изменить';

  @override
  String get delete => 'Удалить';

  @override
  String get copyUsername => 'Скопировать имя пользователя';

  @override
  String get hide => 'Скрыть';

  @override
  String get show => 'Показать';

  @override
  String get copyPassword => 'Скопировать пароль';

  @override
  String get usernameCopied => 'Имя пользователя скопировано';

  @override
  String get passwordCopied => 'Пароль скопирован';

  @override
  String get confirmDelete => 'Подтвердите удаление';

  @override
  String deleteBody(String website) {
    return 'Удалить эту запись для $website?';
  }

  @override
  String get cancel => 'Отмена';

  @override
  String get deleted => 'Удалено';

  @override
  String get generatePassword => 'Сгенерировать пароль';

  @override
  String get length => 'Длина';

  @override
  String get generate => 'Сгенерировать';

  @override
  String get charUpper => 'Заглавные';

  @override
  String get charLower => 'Строчные';

  @override
  String get charDigits => 'Цифры';

  @override
  String get charSpecial => 'Спецсимволы';

  @override
  String get saveToVault => 'Сохранить в хранилище';

  @override
  String get websiteRequired => 'Сайт *';

  @override
  String get usernameOptional => 'Имя пользователя (необязательно)';

  @override
  String get passwordRequired => 'Пароль *';

  @override
  String get save => 'Сохранить';

  @override
  String get websitePasswordEmpty => 'Сайт и пароль не могут быть пустыми';

  @override
  String get saved => 'Сохранено';

  @override
  String get duplicateEntry => 'Такая запись уже существует';

  @override
  String get emptyVault =>
      'Хранилище пусто. Добавьте первую запись на вкладке «Добавить».';

  @override
  String totalCount(int count) {
    return 'Всего: $count';
  }

  @override
  String get sortNameAsc => 'Имя А→Я';

  @override
  String get sortNameDesc => 'Имя Я→А';

  @override
  String get sortTimeDesc => 'Дата добавления (сначала новые)';

  @override
  String get sortTimeAsc => 'Дата добавления (сначала старые)';

  @override
  String get sortTooltip => 'Сортировка';

  @override
  String get decryptFailedCopy =>
      'Не удалось расшифровать текущим мастер-ключом; копирование не выполнено';

  @override
  String get noUsername => '(без имени пользователя)';

  @override
  String get cannotDecrypt => 'Не удаётся расшифровать';

  @override
  String get cannotDecryptBody =>
      'Эту запись нельзя расшифровать текущим мастер-ключом.\nНажмите «Назад» в левом верхнем углу и введите правильный мастер-ключ заново.';

  @override
  String get website => 'Сайт';

  @override
  String get username => 'Имя пользователя';

  @override
  String get password => 'Пароль';

  @override
  String get updated => 'Обновлено';

  @override
  String get sectionLanguage => 'Язык';

  @override
  String get language => 'Язык';

  @override
  String get followSystem => 'Как в системе';

  @override
  String get sectionCloudSync => 'Облачная синхронизация';

  @override
  String get enableCloudSync => 'Включить облачную синхронизацию';

  @override
  String get enableCloudSyncSub =>
      'Если выключено, все данные хранятся только на этом устройстве';

  @override
  String get sectionSyncPrompt => 'Запросы синхронизации';

  @override
  String get promptBeforePull => 'Спрашивать о загрузке перед изменениями';

  @override
  String get promptBeforePullSub =>
      'Показывать запрос «загрузить с удалённого» перед добавлением / изменением / удалением';

  @override
  String get promptAfterPush => 'Спрашивать об отправке после изменений';

  @override
  String get smartSkip => 'Умный пропуск';

  @override
  String get smartSkipSub =>
      'Автоматически пропускать запрос «загрузить», когда на удалённом нет обновлений';

  @override
  String get sectionMaintenance => 'Обслуживание';

  @override
  String get compactNow => 'Сжать журнал сейчас';

  @override
  String get sectionAbout => 'О программе';

  @override
  String get aboutSubtitle =>
      'GitHub: muzi-xiaoren · https://github.com/muzi-xiaoren/PassPro';

  @override
  String compactDone(int count, String size) {
    return 'Сжато: активных записей $count, сэкономлено $size';
  }

  @override
  String compactionStatus(int active, int total, String amp) {
    return 'Сейчас активных $active / строк $total (коэффициент $amp×)';
  }

  @override
  String get backendDisabled => 'Не включено';

  @override
  String get enable => 'Включить';

  @override
  String get roleLabel => 'Роль:';

  @override
  String get repoName => 'Имя репозитория';

  @override
  String get branch => 'Ветка';

  @override
  String get filePath => 'Путь к файлу';

  @override
  String get patHelper =>
      'Хранится в связке ключей ОС; никогда не записывается в файлы';

  @override
  String get testOkNoFile =>
      'Подключение успешно (удалённый файл ещё не существует; будет создан при первой отправке)';

  @override
  String testOkSha(String sha) {
    return 'Подключение успешно (текущий sha=$sha…)';
  }

  @override
  String testFailHttp(String code, String message) {
    return 'Ошибка: HTTP $code $message';
  }

  @override
  String testFail(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get testConnection => 'Проверить подключение';

  @override
  String get pullTitle => 'Сначала загрузить с удалённого?';

  @override
  String get pullMessage =>
      'На удалённом могут быть обновления. Загрузить перед продолжением?';

  @override
  String get pull => 'Загрузить';

  @override
  String get skip => 'Пропустить';

  @override
  String get pushTitle => 'Сохранено локально';

  @override
  String get pushMessage => 'Отправить на удалённый?';

  @override
  String get push => 'Отправить';

  @override
  String get later => 'Позже';

  @override
  String get dontPromptThisSession => 'Не спрашивать снова в этой сессии';

  @override
  String get syncMenu => 'Синхронизация';

  @override
  String get syncPull => 'Загрузить и объединить';

  @override
  String get syncPush => 'Отправить текущие данные';

  @override
  String get syncOverwriteLocal => 'Перезаписать локальные данные облаком';

  @override
  String get syncOverwriteRemote => 'Перезаписать облако локальными данными';

  @override
  String syncOverwriteLocalConfirm(String file) {
    return 'Локальные данные будут перезаписаны файлом $file из облака. Неотправленные локальные изменения будут потеряны. Продолжить?';
  }

  @override
  String syncOverwriteRemoteConfirm(String file) {
    return 'Файл $file в облаке будет перезаписан локальными данными. Текущее содержимое облака будет заменено. Продолжить?';
  }

  @override
  String get continueLabel => 'Продолжить';

  @override
  String get overwroteLocal => 'Локальные данные перезаписаны облаком';

  @override
  String get overwroteRemote => 'Облако перезаписано локальными данными';

  @override
  String get accountMenu => 'Аккаунт';

  @override
  String get changeMasterKey => 'Сменить мастер-ключ';

  @override
  String get newMasterKey => 'Новый мастер-ключ';

  @override
  String get confirmNewMasterKey => 'Подтвердите новый мастер-ключ';

  @override
  String get masterKeyMismatch => 'Мастер-ключи не совпадают';

  @override
  String get masterKeyChanged => 'Мастер-ключ изменён';

  @override
  String get changeMasterKeyHint =>
      'Меняет мастер-ключ, используемый в текущем сеансе. Влияет только на последующее шифрование/расшифровку и не изменяет существующие записи.';
}
