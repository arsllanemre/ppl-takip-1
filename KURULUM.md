# PPL Takip – iPhone'a kurulum

Gerekenler: iPhone (iOS 26 veya üstü), AirPods Pro 3, Windows bilgisayar (sadece ilk kurulumda), ücretsiz bir GitHub hesabı ve Apple hesabın.

## 1. Uygulamayı GitHub'da derle (10-15 dk)

1. github.com'da ücretsiz hesap aç.
2. Sağ üstteki **+** ile **New repository** de. İsim olarak `ppl-takip` yaz, **Private** seç, **Create** de.
3. Açılan sayfada **uploading an existing file** linkine tıkla.
4. Bu zip'i bilgisayarında aç. İçindeki her şeyi (`.github` klasörü dahil) sürükleyip sayfaya bırak ve **Commit changes** de.
   - `.github` klasörü yüklenmezse: repo sayfasında **Add file → Create new file** de, isim kutusuna `.github/workflows/build.yml` yaz, zip'teki aynı dosyanın içeriğini yapıştır ve kaydet.
5. Üstteki **Actions** sekmesine geç. **iOS IPA** işi otomatik başlar. Başlamazsa **Run workflow** butonuna bas.
6. Yeşil tik çıkınca (5-10 dk sürer) işe tıkla. En altta **Artifacts** kısmındaki **PPL-ipa** dosyasını indir ve zip'ten çıkar. Elinde `PPL.ipa` olacak.
   - Kırmızı çarpı çıkarsa hata kaydını kopyalayıp Claude'a gönder, düzeltsin.

## 2. iPhone'u hazırla

1. **Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu**'nu aç. Telefon yeniden başlar.
   - Bu seçenek görünmüyorsa SideStore kurulumundan sonra çıkar.
2. **Ayarlar → [AirPods'un] → Nabız**'ın açık olduğundan emin ol.

## 3. SideStore ile kur

SideStore, uygulamayı ücretsiz Apple hesabınla imzalayıp telefona yükler.

1. **docs.sidestore.io** adresindeki kurulum rehberini takip et. Bilgisayar sadece bu ilk adımda lazım.
2. `PPL.ipa` dosyasını telefona at (iCloud Drive, AirDrop ya da kendine mail).
3. SideStore'u aç: **My Apps → + →** `PPL.ipa`'yı seç. Apple hesabınla giriş yap.
4. Uygulama ana ekranda **PPL Takip** adıyla görünür.

## 4. İlk açılış

- **Antrenmanı başlat · nabız takibi** butonuna bas ve Sağlık izinlerini ver (nabız okuma, antrenman yazma/okuma).
- Nabız birkaç saniye içinde gelmeye başlar. Gelmezse kulaklığın oturuşunu ve AirPods ayarındaki Nabız seçeneğini kontrol et.
- Antrenman bitince **kaydet**'e bas. Nabız takibi durur, antrenman Apple Sağlık'a ve Fitness'a da işlenir.

## 5. Her 7 günde bir

Ücretsiz Apple hesabıyla uygulama 7 günde bir yenilenmeli:
- SideStore'u aç → **My Apps → Refresh All**.
- Unutursan uygulama açılmaz. Verilerin silinmez, yenileyince geri gelir.

## Bilinmesi gerekenler

- Bu web uygulamasından ayrı bir uygulama. 11 Kasım'a kadarki antrenmanların içinde yüklü geliyor. Web uygulamasına sonradan girdiğin kayıtlar buraya otomatik gelmez.
- Ekran antrenman boyunca kapanmaz, nabız takibi uygulama açıkken en sağlıklı çalışır.
