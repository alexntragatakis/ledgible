package receipt

type LineKind string

const (
	KindItem     LineKind = "item"
	KindSubtotal LineKind = "subtotal"
	KindTax      LineKind = "tax"
	KindDiscount LineKind = "discount"
	KindFee      LineKind = "fee"
	KindTip      LineKind = "tip"
	KindTotal    LineKind = "total"
)

type Line struct {
	Kind        LineKind `json:"kind"`
	RawText     string   `json:"raw_text"`
	Description *string  `json:"description"`
	Quantity    *string  `json:"quantity"`
	AmountCents *int64   `json:"amount_cents"`
}

type Extraction struct {
	Merchant    *string `json:"merchant"`
	PurchasedAt *string `json:"purchased_at"`
	Currency    string  `json:"currency"`
	Lines       []Line  `json:"lines"`
	RawText     string  `json:"raw_text"`
}

func (e Extraction) LinesOfKind(k LineKind) []Line {
	var out []Line
	for _, l := range e.Lines {
		if l.Kind == k {
			out = append(out, l)
		}
	}
	return out
}
