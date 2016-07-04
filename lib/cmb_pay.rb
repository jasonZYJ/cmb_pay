require 'date'
require 'uri'
require 'active_support/core_ext/hash'
require 'cmb_pay/version'
require 'cmb_pay/util'
require 'cmb_pay/sign'
require 'cmb_pay/merchant_code'
require 'cmb_pay/message'
require 'cmb_pay/service'

module CmbPay
  class << self
    attr_accessor :branch_id # 开户分行号
    attr_accessor :co_no     # 支付商户号/收单商户号
    attr_accessor :co_key    # 商户校验码，测试环境为空
    attr_accessor :mch_no    # 协议商户企业编号，或者说是8位虚拟企业网银编号
    attr_accessor :expire_in_minutes # 会话有效时间
    attr_accessor :environment # 调用的招商银行支付环境，默认生产，测试填test
    attr_accessor :default_payee_id # 默认收款方的用户标识
  end
  @co_key = ''
  @mch_no = ''
  @expire_in_minutes = 30
  @environment = :production

  def self.uri_of_pre_pay_euserp(payer_id:, bill_no:, amount_in_cents:, merchant_url:, merchant_para: '',
                                 protocol:, merchant_ret_url:, merchant_ret_para: '',
                                 options: {})
    branch_id = options.delete(:branch_id) || CmbPay.branch_id
    co_no = options.delete(:co_no) || CmbPay.co_no
    co_key = options.delete(:co_key) || CmbPay.co_key
    # 定单号，6位或10位长数字，由商户系统生成，一天内不能重复；
    cmb_bill_no = format('%010d', bill_no.to_i % 10_000_000_000)
    expire_in_minutes = options.delete(:expire_in_minutes) || CmbPay.expire_in_minutes
    pay_in_yuan, pay_in_cent = amount_in_cents.to_i.divmod(100)
    pay_amount = "#{pay_in_yuan}.#{pay_in_cent}"
    trade_date = options.delete(:trade_date) || Time.now.strftime('%Y%m%d')
    payee_id = options.delete(:payee_id) || CmbPay.default_payee_id
    random = options.delete(:random)
    protocol[:TS] = Time.now.strftime('%Y%m%d%H%M%S') unless protocol[:TS].nil?
    protocol[:MchNo] = CmbPay.mch_no
    m_code = MerchantCode.generate(random: random, strkey: co_key, date: trade_date,
                                   branch_id: branch_id, co_no: co_no,
                                   bill_no: cmb_bill_no, amount: pay_amount,
                                   merchant_para: merchant_para, merchant_url: merchant_url,
                                   payer_id: payer_id, payee_id: payee_id,
                                   reserved: protocol.to_xml(root: 'Protocol', skip_instruct: true, skip_types: true, indent: 0))
    uri_params = {
      'BranchID' => branch_id,
      'CoNo'     => co_no,
      'BillNo'   => cmb_bill_no,
      'Amount'   => pay_amount,
      'ExpireTimeSpan' => expire_in_minutes,
      'MerchantUrl' => merchant_url,
      'MerchantPara' => merchant_para,
      'MerchantCode' => m_code,
      'MerchantRetUrl' => merchant_ret_url,
      'MerchantRetPara' => merchant_ret_para
    }
    Service.request_uri('PrePayEUserP', uri_params)
  end

  def self.cmb_pay_message(query_string)
    CmbPay::Message.new query_string
  end
end
