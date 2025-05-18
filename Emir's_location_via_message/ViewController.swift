import UIKit
import ContactsUI
import MessageUI
import ObjectiveC.runtime

final class ViewController: UIViewController {

    // MARK: – ipinfo.io token
    private let ipinfoToken = "86ea596d23e4e3"

    // MARK: – “Send Location” butonu
    @IBAction func sendTapped(_ sender: UIButton) {
        fetchIPInfo { [weak self] info in
            guard let self, let info else {
                self?.safeAlert("Konum bilgisi alınamadı."); return
            }

            // ① Google Maps (kısa) link
            let link  = "https://maps.google.com/?q=\(info.lat),\(info.lon)"

            // ② Koordinat metni
            let coord = String(format: "%.5f, %.5f", info.lat, info.lon)

            // ③ Adres (boş olabilir)
            let addr  = [info.city, info.region, info.country]
                          .compactMap { $0 }
                          .joined(separator: ", ")

            // ④ SMS gövdesi
            var body  = """
            Konumum: \(link)
            Koordinat: \(coord)
            """
            if !addr.isEmpty {
                body += "\nAdres: \(addr)"
            }

            // ⑤ UI – ana thread’de
            DispatchQueue.main.async {
                let ac = UIAlertController(title: "Konum ön-izleme",
                                           message: body,
                                           preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "Vazgeç", style: .cancel))
                ac.addAction(UIAlertAction(title: "Gönder", style: .default) { _ in
                    self.presentContactPicker(with: body)
                })
                self.present(ac, animated: true)
            }
        }
    }

    // MARK: – ipinfo.io çağrısı
    private func fetchIPInfo(completion: @escaping (IPInfo?) -> Void) {
        let url = URL(string: "https://ipinfo.io/json?token=\(ipinfoToken)")!
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard   error == nil,
                    let data,
                    let obj  = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
                    let loc  = (obj["loc"] as? String)?.split(separator: ","),
                    loc.count == 2,
                    let lat  = Double(loc[0]),
                    let lon  = Double(loc[1]) else { completion(nil); return }

            completion(.init(lat: lat,
                             lon: lon,
                             city:    obj["city"]    as? String,
                             region:  obj["region"]  as? String,
                             country: obj["country"] as? String))
        }.resume()
    }

    // MARK: – Rehber seçimi
    private func presentContactPicker(with body: String) {
        let picker = CNContactPickerViewController()
        picker.delegate = self
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]

        // Gövdeyi picker’a iliştir
        objc_setAssociatedObject(picker, &Assoc.bodyKey,
                                 body, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        present(picker, animated: true)
    }

    // MARK: – URL query güvenli encode
    private func percentEncode(_ string: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=?")          // ayırıcı karakterleri çıkar
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}

// MARK: – CNContactPickerDelegate
extension ViewController: CNContactPickerDelegate {

    func contactPicker(_ picker: CNContactPickerViewController,
                       didSelect contact: CNContact) {

        picker.dismiss(animated: true) { [weak self] in
            guard let self,
                  let phone = contact.phoneNumbers.first?.value.stringValue else { return }

            let body = objc_getAssociatedObject(picker, &Assoc.bodyKey) as! String

            #if targetEnvironment(simulator)
            // ——— SIMÜLATÖR ———
            let numEnc  = self.percentEncode(phone)
            let bodyEnc = self.percentEncode(body)
            let urlStr  = "sms:/open?addresses=\(numEnc)&body=\(bodyEnc)"

            if let url = URL(string: urlStr) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url)
                }
            } else {
                self.safeAlert("Mesaj URL’si oluşturulamadı.")
            }

            #else
            // ——— GERÇEK CİHAZ ———
            if MFMessageComposeViewController.canSendText() {
                let sms = MFMessageComposeViewController()
                sms.body       = body
                sms.recipients = [phone]          // ham biçim – kişi adı eşleşir
                sms.messageComposeDelegate = self
                self.present(sms, animated: true)
            } else {
                self.safeAlert("Mesaj gönderilemiyor.")
            }
            #endif
        }
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        picker.dismiss(animated: true)
    }
}

// MARK: – SMS Delegate
extension ViewController: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                      didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
    }
}

// MARK: – Modeller & yardımcılar
private struct IPInfo {
    let lat, lon: Double
    let city, region, country: String?
}

private struct Assoc { static var bodyKey = "smsBodyKey" }

extension ViewController {
    func safeAlert(_ msg: String) {
        DispatchQueue.main.async {
            let ac = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "Tamam", style: .default))
            self.present(ac, animated: true)
        }
    }
}
