---
layout: post
title:  "Golang: declarative validation made similar to Ruby on Rails"
date:   2021-04-09 13:26:01 -0300
categories: go validation
---
![Golang: declarative validation made similar to Ruby on Rails](/assets/images/2021-04-09-eaedfc55-e5b8-49c0-a94f-af1623f4aab2/2021-04-09-banner.png)

When it comes for validating input data, boiler plate code with a lot of if conditionals come right in the top of my head. Remembering my experience with Ruby On Rails, I was wondering if it was possible to use declarative validation in [Golang](http://golang.org), in a similar way of [Active Record validations](https://guides.rubyonrails.org/active_record_validations.html). In this article, we'll see how to achieve that.

## The domain model

Let's assume this simple domain:

![No alt text provided for this image](/assets/images/2021-04-09-eaedfc55-e5b8-49c0-a94f-af1623f4aab2/1617918103556.png)

The ' _People_' table has a [**One To Many**](https://en.wikipedia.org/wiki/One-to-many_(data_model)) relationship with ' _Addresses_' table.

Validation constraints for 'People' table:

1. 'name' and 'email' are required fields, and it's mandatory to have at least one address;
2. 'email' must be a valid email;
3. for private individuals, ' [cpf](https://en.wikipedia.org/wiki/CPF_number)' is required;
4. if fulfilled, ' [cpf](https://en.wikipedia.org/wiki/CPF_number)' must be a valid one;
5. for legal entities, ' [cnpj](https://en.wikipedia.org/wiki/CNPJ)' is required;
6. if fulfilled, ' [cnpj](https://en.wikipedia.org/wiki/CNPJ)' must be a valid one;
7. it should be not possible to have a person with both ' [cpf](https://en.wikipedia.org/wiki/CPF_number)' and ' [cnpj](https://en.wikipedia.org/wiki/CNPJ)' fulfilled.

Validation constraints for 'Addresses' table:

1. 'street', 'city' and 'phone' are required fields;
2. 'phone' must be a valid one.

## The Rails way

Creating the project:

```
tiago:~/develop/ruby/rails$ rails new validation-example --api

```

Creating the 'person' model:

```
tiago:~/develop/ruby/rails/validation-example$ rails g model person name:string email:string cpf:string cnpj:string

```

Creating the 'address' model:

```
tiago:~/develop/ruby/rails/validation-example$ rails g model address street:string city:string phone:string

```

Migration file for 'person' model:

```
class CreatePeople < ActiveRecord::Migration[6.1]
  def change
    create_table :people do |t|
      t.string :name
      t.string :email
      t.string :cpf
      t.string :cnpj

      t.timestamps
    end
  end
end

```

Migration file for 'address' model:

```
class CreateAddresses < ActiveRecord::Migration[6.1]
  def change
    create_table :addresses do |t|
      t.belongs_to :person
      t.string :street
      t.string :city
      t.string :phone

      t.timestamps
    end
  end
end

```

Creating the tables:

```
tiago:~/develop/ruby/rails/validation-example$ rails db:migrate
== 20210408191956 CreatePeople: migrating =====================================
-- create_table(:people)
   -> 0.0017s
== 20210408191956 CreatePeople: migrated (0.0018s) ============================

== 20210408192152 CreateAddresses: migrating ==================================
-- create_table(:addresses)
   -> 0.0029s
== 20210408192152 CreateAddresses: migrated (0.0030s) =========================

```

### Adding validation

**person.rb:**

```
class Person < ApplicationRecord
	has_many :addresses, dependent: :destroy, index_errors: true
	accepts_nested_attributes_for :addresses
	validates :name, :email, :addresses, presence: true
	validates :email, format: { with: /\A[a-zA-Z0-9_\-\.]+@[a-zA-Z0-9_\-\.]+\.[a-zA-Z]{2,5}\z/, message: "is invalid" }
	validates :cpf, allow_blank: true, format: { with: /\A\d{3}.\d{3}.\d{3}-\d{2}$\z/, message: "is invalid" }
	validates :cnpj, allow_blank: true, format: { with: /\A\d{2}\.\d{3}\.\d{3}\/\d{4}\-\d{2}\z/, message: "is invalid" }

	validate :cpf_or_cnpj

	def cpf_or_cnpj
		if cpf.present? && cnpj.present?
			errors.add(:base, "either cpf or cpnj must be informed")
		end
		if cpf.nil? && cnpj.nil?
			errors.add(:base, "cpf or cpnj must be informed")
		end
	end
end

```

- validating the presence of 'name', 'email' and 'addresses';
- validating the format of 'email', 'cpf' and 'cnpj' through [regular expressions](https://en.wikipedia.org/wiki/Regular_expression);
- custom validation method that checks if both 'cpf' and 'cnpj' are fulfilled or if none are present.

**address.rb**:

```
class Address < ApplicationRecord
	belongs_to :person
	validates :street, :city, :phone, presence: true
	validates :phone, format: { with: /\A\+[1-9]\d{1,14}\z/, message: "is invalid" }
end

```

- validating the presence of 'street', 'city' and 'phone';
- validating the format of 'phone' to [E164 format](https://en.wikipedia.org/wiki/E.164).

### Running it

Let's play a bit with it. First, we need to launch the [rails console](https://guides.rubyonrails.org/command_line.html#bin-rails-console):

```
tiago:~/develop/ruby/rails/validation-example$ rails c
Running via Spring preloader in process 14714

Loading development environment (Rails 6.1.3.1)
3.0.0 :001 >

```

Now, we'll test some scenarios to check if the validations work. It's a matter of creating a 'Person' object and calling 'save!' method, which will tell us what are the validation errors.

**Missing required fields in 'person':**

```
3.0.0 :001 > Person.new().save!
   (0.6ms)  SELECT sqlite_version(*)
  TRANSACTION (0.1ms)  begin transaction
  TRANSACTION (0.1ms)  rollback transaction
Traceback (most recent call last):
        1: from (irb):1:in `<main>'
ActiveRecord::RecordInvalid (Validation failed: Name can't be blank, Email can't be blank, Addresses can't be blank, Email is invalid, cpf or cpnj must be informed)

3.0.0 :002 >

```

**Missing required fields in 'address':**

```
3.0.0 :002?> Person.new(name: "Steve", email: "steve@maiden.com", cpf:"666.666.666-66", addresses:[Address.new()]).save!
Traceback (most recent call last):
        2: from (irb):1:in `<main>'
        1: from (irb):2:in `rescue in <main>'

ActiveRecord::RecordInvalid (Validation failed: Addresses[0] street can't be blank, Addresses[0] city can't be blank, Addresses[0] phone can't be blank, Addresses[0] phone is invalid)

```

**Two addresses: one is valid, the other two are missing required fields:**

```
3.0.0 :003 > Person.new(name: "Steve", email: "steve@maiden.com", cpf:"666.666.666-66", addresses:[Address.new(), Address.new(street:"some street", city:"some city", phone: "+5511111112222"), Address.new()]).save!
Traceback (most recent call last):
        2: from (irb):2:in `<main>'
        1: from (irb):3:in `rescue in <main>'

ActiveRecord::RecordInvalid (Validation failed: Addresses[0] street can't be blank, Addresses[0] city can't be blank, Addresses[0] phone can't be blank, Addresses[0] phone is invalid, Addresses[2] street can't be blank, Addresses[2] city can't be blank, Addresses[2] phone can't be blank, Addresses[2] phone is invalid)

```

**Invalid phone in address:**

```
3.0.0 :040 > Person.new(name: "Steve", email: "steve@maiden.com", cpf:"666.666.666-66", addresses:[Address.new(street: "some street", city: "some city", phone: "111")]).save!
   (0.1ms)  SELECT sqlite_version(*)
Traceback (most recent call last):
        1: from (irb):40:in `<main>'

ActiveRecord::RecordInvalid (Validation failed: Addresses[0] phone is invalid)

```

**Invalid email:**

```
3.0.0 :041 > Person.new(name: "Steve", email: "invalid@email", cpf:"666.666.666-66", addresses:[Address.new(street: "some street", city: "some city", phone: "+551111111111"
)]).save!
Traceback (most recent call last):
        2: from (irb):40:in `<main>'
        1: from (irb):41:in `rescue in <main>'

ActiveRecord::RecordInvalid (Validation failed: Email is invalid)

```

**Invalid** [**cpf**](https://en.wikipedia.org/wiki/CPF_number) **:**

```
3.0.0 :042 > Person.new(name: "Steve", email: "steve@maiden.com", cpf:"666", addresses:[Address.new(street: "some street", city: "some city", phone: "+551111111111")]).save!
Traceback (most recent call last):
        2: from (irb):41:in `<main>'
        1: from (irb):42:in `rescue in <main>'

ActiveRecord::RecordInvalid (Validation failed: Cpf is invalid)

```

**Invalid** [**cnpj**](https://en.wikipedia.org/wiki/CNPJ) **:**

```
3.0.0 :043 > Person.new(name: "Steve", email: "steve@maiden.com", cnpj:"666", addresses:[Address.new(street: "some street", city: "some city", phone: "+551111111111")]).save!
Traceback (most recent call last):
        2: from (irb):42:in `<main>'
        1: from (irb):43:in `rescue in <main>'

ActiveRecord::RecordInvalid (Validation failed: Cnpj is invalid)

```

**Both** [**cpf**](https://en.wikipedia.org/wiki/CPF_number) **and** [**cnpj**](https://en.wikipedia.org/wiki/CNPJ) **are present:**

```
3.0.0 :046 > Person.new(name: "Steve", email: "steve@maiden.com", cpf:"666.666.666-66",cnpj:"66.666.666/6666-66",  addresses:[Address.new(street: "some street", city: "some
 city", phone: "+551111111111")]).save!
Traceback (most recent call last):
        2: from (irb):43:in `<main>'
        1: from (irb):44:in `rescue in <main>'

ActiveRecord::RecordInvalid (Validation failed: either cpf or cpnj must be informed)

```

## The Golang way

When searching for an alternative, I've found the [Validator](https://github.com/go-playground/validator) lib, and it's awesome. Its main features are struct and field validation, including Cross Field, Cross Struct, Map, Slice and Array diving. And it even offers some [out-of-box, baked-in validations](https://github.com/go-playground/validator#baked-in-validations).

### Sample project

I've written a sample Golang project to show how to achieve similar results that were demonstrated in the Rails project above. The idea is to make it possible to run the same validation scenarios with the help of fixture files.

**app/data/person.go:**

```
package person

type Person struct {
    Name      string     `yaml:"name" json:"name" validate:"required"`
    Email     string     `yaml:"email" json:"email" validate:"required,email"`
    Cpf       string     `yaml:"cpf" json:"cpf" validate:"omitempty,cpf"`
    Cnpj      string     `yaml:"cnpj" json:"cnpj" validate:"omitempty,cnpj"`
    Addresses []*Address `yaml:"addresses" json:"addresses" validate:"required,dive,required"`
}

type Address struct {
    Street string `yaml:"street" json:"street" validate:"required"`
    City   string `yaml:"city" json:"city" validate:"required"`
    Phone  string `yaml:"phone" json:"phone" validate:"required,e164"`
}

```

- the 'yaml' tag here is to make it possible to parse a yaml file to both 'Person' and 'Address' structs via the excellent [Go-yaml](https://github.com/go-yaml/yaml/tree/v3) lib;
- 'Name' and 'Email' are marked as required fields via 'validate:"required"' tag;
- 'Email' is validated using 'email' validate tag, which is a backed-in validation;
- 'Cpf' is validated using a custom tag called 'cpf', which will check its format;
- 'Cnpj' is validated using a custom tag called 'cnpj', which will check its format;
- 'Addresses' is an array of 'Address' struct, and we'll make sure that every element in this array will be validated through the use of the 'dive' validation tag;
- 'Street', 'City' and 'Phone' are marked as required fields via 'validate:"required" tag;
- 'Phone' is validated using the 'e164' tag, which is a backed-in validation.

Now, let's see how to implement the validations.

**app/validate/validate.go:**

```
package validate

import (
    "encoding/json"
    "fmt"
    "reflect"
    "regexp"
    "strings"

    "bitbucket.org/tiagoharris/golang-validator-example/app/data/person"
    "github.com/go-playground/locales/en"
    ut "github.com/go-playground/universal-translator"
    "github.com/go-playground/validator/v10"
    en_translations "github.com/go-playground/validator/v10/translations/en"
    "github.com/pkg/errors"
)

type Validate struct {
    *validator.Validate
    Trans ut.Translator
}

// FieldError is used to indicate an error with a specific field
type FieldError struct {
    Field string `json:"field,omitempty"`
    Error string `json:"error"`
}

// FieldErrors represents a collection of field errors
type FieldErrors []FieldError

// Error returns a string for failed fields
func (fe FieldErrors) Error() string {
    d, err := json.Marshal(fe)
    if err != nil {
        return err.Error()
    }
    return string(d)
}

func registerValidationForCpfTag(fl validator.FieldLevel) bool {
    cpfRegexp := regexp.MustCompile(`^\d{3}.\d{3}.\d{3}-\d{2}$`)
    return cpfRegexp.MatchString(fl.Field().String())
}

func registerTranslationForCpfTag(ut ut.Translator) error {
    return ut.Add("cpf", "{0} {1} is invalid", true)
}

func translationForCpfTag(ut ut.Translator, fe validator.FieldError) string {
    t, _ := ut.T("cpf", fe.Field(), fmt.Sprintf("%v", fe.Value()))
    return t
}

func registerTranslationForEmailTag(ut ut.Translator) error {
    return ut.Add("email", "{0} {1} is invalid", true)
}

func translationForEmailTag(ut ut.Translator, fe validator.FieldError) string {
    t, _ := ut.T("email", fe.Field(), fmt.Sprintf("%v", fe.Value()))
    return t
}

func registerValidationForCnpjTag(fl validator.FieldLevel) bool {
    cnpjRegexp := regexp.MustCompile(`^\d{2}\.\d{3}\.\d{3}\/\d{4}\-\d{2}$`)
    return cnpjRegexp.MatchString(fl.Field().String())
}

func registerTranslationForCnpjTag(ut ut.Translator) error {
    return ut.Add("cnpj", "{0} {1} is invalid", true)
}

func translationForCnpjTag(ut ut.Translator, fe validator.FieldError) string {
    t, _ := ut.T("cnpj", fe.Field(), fmt.Sprintf("%v", fe.Value()))
    return t
}

func registerTranslationForCpfOrCnpj(ut ut.Translator) error {
    return ut.Add("cpf_or_cnpj", "cpf or cpnj must be informed", true)
}

func translationForCpfOrCnpj(ut ut.Translator, fe validator.FieldError) string {
    t, _ := ut.T("cpf_or_cnpj", fe.Field())
    return t
}

func registerTranslationForCpfAndCnpj(ut ut.Translator) error {
    return ut.Add("cpf_and_cnpj", "Either cpf or cpnj must be informed", true)
}

func translationForCpfAndCnpj(ut ut.Translator, fe validator.FieldError) string {
    t, _ := ut.T("cpf_and_cnpj", fe.Field())
    return t
}

func registerTranslationForE164Tag(ut ut.Translator) error {
    return ut.Add("e164", "{0} {1} is invalid. Example of a valid one: +551155256325", true)
}

func translationForE164Tag(ut ut.Translator, fe validator.FieldError) string {
    t, _ := ut.T("e164", fe.Field(), fmt.Sprintf("%v", fe.Value()))
    return t
}

func NewValidate(locale string) (Validate, error) {
    translator := en.New()
    uni := ut.New(translator, translator)

    trans, found := uni.GetTranslator(locale)
    if !found {
        return Validate{}, errors.Errorf("getting translator for '%s' locale", locale)
    }

    v := validator.New()

    // registers a set of default translations for all built in tags in validator
    if err := en_translations.RegisterDefaultTranslations(v, trans); err != nil {
        return Validate{}, errors.Errorf("registering default translations for '%s' locale", locale)
    }

    // register function to get tag name from json tags
    v.RegisterTagNameFunc(func(fld reflect.StructField) string {
        name := strings.SplitN(fld.Tag.Get("json"), ",", 2)[0]
        if name == "-" {
            return ""
        }
        return name
    })

    // registers validation logic for "cpf" tag
    if err := v.RegisterValidation("cpf", registerValidationForCpfTag); err != nil {
        return Validate{}, errors.New("registering validation for 'cpf' tag")
    }

    // registers validation logic for "cnpj" tag
    if err := v.RegisterValidation("cnpj", registerValidationForCnpjTag); err != nil {
        return Validate{}, errors.New("registering validation for 'cnpj' tag")
    }

    // registers custom translation message when "email" validation is violated
    if err := v.RegisterTranslation("email", trans, registerTranslationForEmailTag, translationForEmailTag); err != nil {
        return Validate{}, errors.New("registering translation for 'email'")
    }

    // registers custom translation message when "cpf" validation is violated
    if err := v.RegisterTranslation("cpf", trans, registerTranslationForCpfTag, translationForCpfTag); err != nil {
        return Validate{}, errors.New("registering translation for 'cpf'")
    }

    // registers custom translation message when "cnpj" validation is violated
    if err := v.RegisterTranslation("cnpj", trans, registerTranslationForCnpjTag, translationForCnpjTag); err != nil {
        return Validate{}, errors.New("registering translation for 'cnpj'")
    }

    // registers custom translation message when "e164" validation is violated
    if err := v.RegisterTranslation("e164", trans, registerTranslationForE164Tag, translationForE164Tag); err != nil {
        return Validate{}, errors.New("registering translation for 'e164'")
    }

    // registers custom translation message when "cpf_or_cnpj" error tag is reported
    if err := v.RegisterTranslation("cpf_or_cnpj", trans, registerTranslationForCpfOrCnpj, translationForCpfOrCnpj); err != nil {
        return Validate{}, errors.New("registering translation for 'cpf_or_cnpj'")
    }

    // registers custom translation message when "cpf_and_cnpj" error tag is reported
    if err := v.RegisterTranslation("cpf_and_cnpj", trans, registerTranslationForCpfAndCnpj, translationForCpfAndCnpj); err != nil {
        return Validate{}, errors.New("registering translation for 'cpf_and_cnpj'")
    }

    v.RegisterStructValidation(PersonStructLevelValidation, person.Person{})

    return Validate{v, trans}, nil
}

// Checks errors for a  given interface and returns validator.ValidationErrors
func (v Validate) Check(val interface{}) (validator.ValidationErrors, error) {
    if err := v.Struct(val); err != nil {
        verrors, ok := err.(validator.ValidationErrors)
        if !ok {
            return nil, err
        }
        return verrors, nil
    }
    return nil, nil
}

// Checks errors for a  given interface and returns FieldError. It's useful
// for building a json response
func (v Validate) CheckFieldErrors(val interface{}) error {
    if err := v.Struct(val); err != nil {
        verrors, ok := err.(validator.ValidationErrors)
        if !ok {
            return err
        }
        var fields FieldErrors
        for _, verror := range verrors {
            field := FieldError{
                Field: verror.Field(),
                Error: verror.Translate(v.Trans),
            }
            fields = append(fields, field)
        }
        return fields
    }
    return nil
}

func PersonStructLevelValidation(sl validator.StructLevel) {
    req := sl.Current().Interface().(person.Person)
    if len(req.Cpf) == 0 && len(req.Cnpj) == 0 {
        sl.ReportError(nil, "", "", "cpf_or_cnpj", "")
    } else if len(req.Cpf) != 0 && len(req.Cnpj) != 0 {
        sl.ReportError(nil, "", "", "cpf_and_cnpj", "")
    }
}

```

Let's break it down.

```
    translator := en.New()
    uni := ut.New(translator, translator)

    trans, found := uni.GetTranslator(locale)
    if !found {
        return Validate{}, errors.Errorf("getting translator for '%s' locale", locale)
    }

    v := validator.New()

    // registers a set of default translations for all built in tags in validator
    if err := en_translations.RegisterDefaultTranslations(v, trans); err != nil {
        return Validate{}, errors.Errorf("registering default translations for '%s' locale", locale)
    }

```

Here we are initializing the [translator](http://github.com/go-playground/validator/v10/translations/en) for english language, and we registers the set of default translations for all built in tags in the validator.

```
    // register function to get tag name from json tags
    v.RegisterTagNameFunc(func(fld reflect.StructField) string {
        name := strings.SplitN(fld.Tag.Get("json"), ",", 2)[0]
        if name == "-" {
            return ""
        }
        return name
    })

```

Here we're making it possible to use the 'json' tag in error messages instead of the field name in the struct. So, for example, for email, it will be displayed as 'email', not 'Email':

```
type Person struct {
...
  Email     string     `yaml:"email" json:"email" validate:"required,email"`
}

```

Here we are registering the validation logic for "cpf" tag:

```
    // registers validation logic for "cpf" tag
    if err := v.RegisterValidation("cpf", registerValidationForCpfTag); err != nil {
        return Validate{}, errors.New("registering validation for 'cpf' tag")
    }

```

If you take a look into 'registerValidationForCpfTag' function, it validates the field's value against a [regular expression](https://en.wikipedia.org/wiki/Regular_expression):

```
func registerValidationForCpfTag(fl validator.FieldLevel) bool {
    cpfRegexp := regexp.MustCompile(`^\d{3}.\d{3}.\d{3}-\d{2}$`)
    return cpfRegexp.MatchString(fl.Field().String())
}

```

Here we are registering the validation logic for "cnpj" tag:

```
    // registers validation logic for "cnpj" tag
    if err := v.RegisterValidation("cnpj", registerValidationForCnpjTag); err != nil {
        return Validate{}, errors.New("registering validation for 'cnpj' tag")
    }

```

The 'registerValidationForCnpjTag' function validates the field's value against a [regular expression](https://en.wikipedia.org/wiki/Regular_expression):

```
func registerValidationForCnpjTag(fl validator.FieldLevel) bool {
    cnpjRegexp := regexp.MustCompile(`^\d{2}\.\d{3}\.\d{3}\/\d{4}\-\d{2}$`)
    return cnpjRegexp.MatchString(fl.Field().String())
}

```

Now, the interesting part. We want to customize the error messages when using the [baked-in validations](https://github.com/go-playground/validator#baked-in-validations). Let's see how we do it for 'email' tag:

```
    // registers custom translation message when "email" validation is violated
    if err := v.RegisterTranslation("email", trans, registerTranslationForEmailTag, translationForEmailTag); err != nil {
        return Validate{}, errors.New("registering translation for 'email'")
}

```

If you take a look into 'translationForEmailTag' function, you'll see that for struct fields marked with 'email' tag, we'll display the field's name (which is, "email") along with it's current value. So we are displaying two values, right?

```
func translationForEmailTag(ut ut.Translator, fe validator.FieldError) string {
    t, _ := ut.T("email", fe.Field(), fmt.Sprintf("%v", fe.Value()))
    return t
}

```

Then, in 'registerTranslationForEmailTag' function, we are building the way the error message will be displayed:

```
func registerTranslationForEmailTag(ut ut.Translator) error {
    return ut.Add("email", "{0} {1} is invalid", true)
}

```

where '{0}' will be replaced by the field's name ("email") and '{1}' will be replaced with the field's value.

We do the same for 'cpf', 'cnpj' and 'e164' tags.

### Custom validations

We saw at the beginning of this article what were the validation constraints. Since the 'Person' struct holds all the information we want to validate, we then register it for struct validation:

```
v.RegisterStructValidation(PersonStructLevelValidation, person.Person{})

```

And then, in 'PersonStructLevelValidation' function, we put the logic we want: a person might have 'cpf' OR 'cnpj', not both:

```
func PersonStructLevelValidation(sl validator.StructLevel) {
    req := sl.Current().Interface().(person.Person)
    if len(req.Cpf) == 0 && len(req.Cnpj) == 0 {
        sl.ReportError(nil, "", "", "cpf_or_cnpj", "")
    } else if len(req.Cpf) != 0 && len(req.Cnpj) != 0 {
        sl.ReportError(nil, "", "", "cpf_and_cnpj", "")
    }
}

```

As you see here, if both are missing, an error is reported for the 'cpf\_or\_cnpj' tag. If both are fulfilled, an error is reported for 'cpf\_and\_cnpj' tag.

And then we register custom translations for each of these tags, 'cpf\_or\_cnpj' and 'cpf\_and\_cnpj':

```
    // registers custom translation message when "cpf_or_cnpj" error tag is reported
    if err := v.RegisterTranslation("cpf_or_cnpj", trans, registerTranslationForCpfOrCnpj, translationForCpfOrCnpj); err != nil {
        return Validate{}, errors.New("registering translation for 'cpf_or_cnpj'")
    }

    // registers custom translation message when "cpf_and_cnpj" error tag is reported
    if err := v.RegisterTranslation("cpf_and_cnpj", trans, registerTranslationForCpfAndCnpj, translationForCpfAndCnpj); err != nil {
        return Validate{}, errors.New("registering translation for 'cpf_and_cnpj'")
    }

```

These are the functions that formats the error messages:

```
func registerTranslationForCpfOrCnpj(ut ut.Translator) error {
    return ut.Add("cpf_or_cnpj", "cpf or cpnj must be informed", true)
}

func translationForCpfOrCnpj(ut ut.Translator, fe validator.FieldError) string {
    t, _ := ut.T("cpf_or_cnpj", fe.Field())
    return t
}

func registerTranslationForCpfAndCnpj(ut ut.Translator) error {
    return ut.Add("cpf_and_cnpj", "Either cpf or cpnj must be informed", true)
}

func translationForCpfAndCnpj(ut ut.Translator, fe validator.FieldError) string {
    t, _ := ut.T("cpf_and_cnpj", fe.Field())
    return t
}

```

The **Check** function returns [validator.ValidationErrors](https://pkg.go.dev/gopkg.in/go-playground/validator.v9#ValidationErrors), which is a nice option for a standalone app. Then it's a matter of looping through the array and translating each error:

```
    if verrors, err := v.Check(person); err != nil {
        return errors.Wrap(err, "calling Check()")
    } else {
        if len(verrors) > 0 {
            fmt.Println("")
            fmt.Println("############################################")
            fmt.Println("## simple output                          ##")
            fmt.Println("############################################")
            fmt.Println("")
            fmt.Println("found error(s):")
            for _, e := range verrors {
                fmt.Printf("- %v\n", e.Translate(v.Trans))
            }
        }
    }

```

The **CheckFieldErrors** function returns a custom struct called **FieldErrors,** which, in turn, could be used as a [JSON](https://www.json.org/) response:

```
    if err := v.CheckFieldErrors(person); err != nil {
        fmt.Println("")
        fmt.Println("############################################")
        fmt.Println("## json output                            ##")
        fmt.Println("############################################")
        fmt.Println("")
        fmt.Println("found error(s):")

        prettyJSON, err := json.MarshalIndent(err, "", "  ")
        if err != nil {
            errors.Wrap(err, "pretty printing json")
            os.Exit(1)
        }
        fmt.Println(string(prettyJSON))
    }

```

### **Running it**

To ease the demonstration, I've written fixture files that represents each validation scenario we want to test:

![No alt text provided for this image](/assets/images/2021-04-09-eaedfc55-e5b8-49c0-a94f-af1623f4aab2/1617922623416.png)

Our **main.go** file reads the given yaml file, parses it into Person struct and validates it. Then, it shows two different outputs: one by calling **Check** function and the other by calling **CheckFieldErrors** function.

**Missing required fields in 'person':**

```
tiago:~/develop/go/golang-validator-example$ make run FIXTURE_FILE=app/fixtures/empty_person.yaml

############################################

## simple output                          ##

############################################

found error(s):

- name is a required field

- email is a required field

- addresses is a required field

- cpf or cpnj must be informed

############################################

## json output                            ##

############################################

found error(s):

[

  {

    "field": "name",

    "error": "name is a required field"

  },

  {

    "field": "email",

    "error": "email is a required field"

  },

  {

    "field": "addresses",

    "error": "addresses is a required field"

  },

  {

    "error": "cpf or cpnj must be informed"

  }
]

```

**Missing required fields in 'address':**

```
tiago:~/develop/go/golang-validator-example$ make run FIXTURE_FILE=app/fixtures/person_empty_address.yaml

############################################

## simple output                          ##

############################################

found error(s):

- street is a required field

- city is a required field

- phone is a required field

############################################

## json output                            ##

############################################

found error(s):

[

  {

    "field": "street",

    "error": "street is a required field"

  },

  {

    "field": "city",

    "error": "city is a required field"

  },

  {

    "field": "phone",

    "error": "phone is a required field"

  }
]

```

**Two addresses: one is valid, the other two are missing required fields:**

```
tiago:~/develop/go/golang-validator-example$ make run FIXTURE_FILE=app/fixtures/person_empty_addresses.yaml

############################################

## simple output                          ##

############################################

found error(s):

- street is a required field

- city is a required field

- phone is a required field

- street is a required field

- city is a required field

- phone is a required field

############################################

## json output                            ##

############################################

found error(s):

[

  {

    "field": "street",

    "error": "street is a required field"

  },

  {

    "field": "city",

    "error": "city is a required field"

  },

  {

    "field": "phone",

    "error": "phone is a required field"

  },

  {

    "field": "street",

    "error": "street is a required field"

  },

  {

    "field": "city",

    "error": "city is a required field"

  },

  {

    "field": "phone",

    "error": "phone is a required field"

  }
]

```

**Invalid phone in address:**

```
tiago:~/develop/go/golang-validator-example$ make run FIXTURE_FILE=app/fixtures/person_invalid_phone.yaml

############################################

## simple output                          ##

############################################

found error(s):

- phone 111 is invalid. Example of a valid one: +551155256325

############################################

## json output                            ##

############################################

found error(s):

[

  {

    "field": "phone",

    "error": "phone 111 is invalid. Example of a valid one: +551155256325"

  }
]

```

**Invalid email:**

```
tiago:~/develop/go/golang-validator-example$ make run FIXTURE_FILE=app/fixtures/person_invalid_email.yaml

############################################

## simple output                          ##

############################################

found error(s):

- email invalid@email is invalid

############################################

## json output                            ##

############################################

found error(s):

[

  {

    "field": "email",

    "error": "email invalid@email is invalid"

  }
]

```

**Invalid** [**cpf**](https://en.wikipedia.org/wiki/CPF_number) **:**

```
tiago:~/develop/go/golang-validator-example$ make run FIXTURE_FILE=app/fixtures/person_invalid_cpf.yaml

############################################

## simple output                          ##

############################################

found error(s):

- cpf 111 is invalid

############################################

## json output                            ##

############################################

found error(s):

[

  {

    "field": "cpf",

    "error": "cpf 111 is invalid"

  }
]

```

**Invalid** [**cnpj**](https://en.wikipedia.org/wiki/CNPJ) **:**

```
tiago:~/develop/go/golang-validator-example$ make run FIXTURE_FILE=app/fixtures/person_invalid_cnpj.yaml

############################################

## simple output                          ##

############################################

found error(s):

- cnpj 111 is invalid

############################################

## json output                            ##

############################################

found error(s):

[

  {

    "field": "cnpj",

    "error": "cnpj 111 is invalid"

  }
]

```

**Both** [**cpf**](https://en.wikipedia.org/wiki/CPF_number) **and** [**cnpj**](https://en.wikipedia.org/wiki/CNPJ) **are present:**

```
tiago:~/develop/go/golang-validator-example$ make run FIXTURE_FILE=app/fixtures/person_both_cpf_cnpj.yaml

############################################

## simple output                          ##

############################################

found error(s):

- Either cpf or cpnj must be informed

############################################

## json output                            ##

############################################

found error(s):

[

  {

    "error": "Either cpf or cpnj must be informed"

  }
]

```

Pretty cool, isn't it?

## Conclusion

In this article, we've learned how to leverage struct validation via [Validator](https://github.com/go-playground/validator) lib, which is awesome. Using that we can isolate our field validation and reuse tags in other structs. I'm using it in my production projects and I'm pretty satisfied.

## Download the source

Here: [http://bitbucket.org/tiagoharris/golang-validator-example](http://bitbucket.org/tiagoharris/golang-validator-example)