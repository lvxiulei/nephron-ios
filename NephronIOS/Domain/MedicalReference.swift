import Foundation

/// 本地引用资料；外链为固定公开地址，不包含任何用户输入或检验记录。
struct MedicalReference: Identifiable {
    let id: String
    let organization: String
    let title: String
    let originalTitle: String
    let scope: String
    let url: URL

    static let all: [MedicalReference] = [
        MedicalReference(
            id: "1", organization: "美国国家肾脏基金会 · NKF",
            title: "CKD-EPI 2021 血肌酐公式",
            originalTitle: "CKD-EPI Creatinine Equation (2021)",
            scope: "公式、性别系数、变量与单位。",
            url: URL(string: "https://www.kidney.org/ckd-epi-creatinine-equation-2021")!
        ),
        MedicalReference(
            id: "2", organization: "美国国立糖尿病、消化与肾脏疾病研究所 · NIDDK",
            title: "成人 eGFR 公式",
            originalTitle: "eGFR Equations for Adults",
            scope: "成人适用范围、单位换算、估算局限、趋势与尿白蛋白评估。",
            url: URL(string: "https://www.niddk.nih.gov/research-funding/research-programs/kidney-clinical-research-epidemiology/laboratory/glomerular-filtration-rate-equations/adults")!
        ),
        MedicalReference(
            id: "3", organization: "美国国家肾脏基金会 · NKF",
            title: "认识 eGFR 检查",
            originalTitle: "Estimated Glomerular Filtration Rate (eGFR)",
            scope: "估算与实测的区别、影响因素，以及结合其他检查理解结果。",
            url: URL(string: "https://www.kidney.org/kidney-topics/estimated-glomerular-filtration-rate-egfr")!
        ),
        MedicalReference(
            id: "4", organization: "美国国家肾脏基金会 · NKF",
            title: "GFR 数值区间与 CKD 分类",
            originalTitle: "How to Classify CKD",
            scope: "结果区间的划分；区间本身不能替代疾病诊断。",
            url: URL(string: "https://www.kidney.org/how-to-classify-ckd")!
        ),
    ]

    static let formula = "eGFR = 142 × min(Scr/κ, 1)^α × max(Scr/κ, 1)^−1.200 × 0.9938^年龄 × 性别系数"
    static let coefficients = "女性：κ = 0.7，α = −0.241，性别系数 = 1.012\n男性：κ = 0.9，α = −0.302，性别系数 = 1"
    static let applicability = "用于 18 岁及以上成人的血肌酐估算。eGFR 并非实测值，不能单凭一次结果诊断肾脏疾病。[1–3]"
    static let conversion = "Scr 为血肌酐（mg/dL），年龄以岁计；μmol/L 除以 88.4 换算为 mg/dL。结果单位为 mL/min/1.73 m²。[1, 2]"
}
